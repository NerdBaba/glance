import AppKit
import Combine
import Foundation

// MARK: - Playback State

/// Represents the current playback state.
enum PlaybackState: String {
    case playing, paused, stopped
}

// MARK: - Now Playing Song Model

/// A model representing the currently playing song.
struct NowPlayingSong: Equatable, Identifiable {
    var id: String { title + artist }
    let appName: String
    var state: PlaybackState
    let title: String
    let artist: String
    let album: String
    let albumArtURL: URL?
    let position: Double?
    let duration: Double?  // Duration in seconds

    /// Direct initializer (used by MediaRemote provider).
    init(appName: String, state: PlaybackState, title: String, artist: String,
         album: String, albumArtURL: URL?, position: Double?, duration: Double?) {
        self.appName = appName
        self.state = state
        self.title = title
        self.artist = artist
        self.album = album
        self.albumArtURL = albumArtURL
        self.position = position
        self.duration = duration
    }

    /// Initializes a song model from a given output string.
    /// - Parameters:
    ///   - application: The name of the music application.
    ///   - output: The output string returned by AppleScript.
    init?(application: String, from output: String) {
        let components = output.components(separatedBy: "|")
        guard components.count == 7,
            let state = PlaybackState(rawValue: components[0])
        else {
            return nil
        }
        // Replace commas with dots for correct decimal conversion.
        let positionString = components[5].replacingOccurrences(
            of: ",", with: ".")
        let durationString = components[6].replacingOccurrences(
            of: ",", with: ".")
        guard let position = Double(positionString),
            let duration = Double(durationString)
        else {
            return nil
        }

        self.appName = application
        self.state = state
        self.title = components[1]
        self.artist = components[2]
        self.album = components[3]
        self.albumArtURL = URL(string: components[4])
        self.position = position
        if application == MusicApp.spotify.rawValue {
            self.duration = duration / 1000
        } else {
            self.duration = duration
        }
    }
}

// MARK: - Supported Music Applications

/// Supported music applications with corresponding AppleScript commands.
enum MusicApp: String, CaseIterable {
    case spotify = "Spotify"
    case music = "Music"

    /// AppleScript to fetch the now playing song.
    var nowPlayingScript: String {
        if self == .music {
            return """
                if application "Music" is running then
                    tell application "Music"
                        if player state is playing or player state is paused then
                            set currentTrack to current track
                            try
                                set artworkURL to (get URL of artwork 1 of currentTrack) as text
                            on error
                                set artworkURL to ""
                            end try
                            try
                                set albumName to (album of currentTrack) as text
                            on error
                                set albumName to ""
                            end try
                            set stateText to ""
                            if player state is playing then
                                set stateText to "playing"
                            else if player state is paused then
                                set stateText to "paused"
                            end if
                            return stateText & "|" & (name of currentTrack) & "|" & (artist of currentTrack) & "|" & albumName & "|" & artworkURL & "|" & (player position as text) & "|" & ((duration of currentTrack) as text)
                        else
                            return "stopped"
                        end if
                    end tell
                else
                    return "stopped"
                end if
                """
        } else {
            return """
                if application "\(rawValue)" is running then
                    tell application "\(rawValue)"
                        if player state is playing then
                            set currentTrack to current track
                            return "playing|" & (name of currentTrack) & "|" & (artist of currentTrack) & "|" & (album of currentTrack) & "|" & (artwork url of currentTrack) & "|" & player position & "|" & (duration of currentTrack)
                        else if player state is paused then
                            set currentTrack to current track
                            return "paused|" & (name of currentTrack) & "|" & (artist of currentTrack) & "|" & (album of currentTrack) & "|" & (artwork url of currentTrack) & "|" & player position & "|" & (duration of currentTrack)
                        else
                            return "stopped"
                        end if
                    end tell
                else
                    return "stopped"
                end if
                """
        }
    }

    var previousTrackCommand: String {
        "tell application \"\(rawValue)\" to previous track"
    }

    var togglePlayPauseCommand: String {
        "tell application \"\(rawValue)\" to playpause"
    }

    var nextTrackCommand: String {
        "tell application \"\(rawValue)\" to next track"
    }
}

// MARK: - Now Playing Provider

/// Provides functionality to fetch the now playing song and execute playback commands.
final class NowPlayingProvider {
    /// Cache of compiled AppleScripts — compilation is expensive, execution is cheap.
    private static var compiledScripts: [String: NSAppleScript] = [:]
    /// Serializes access to compiledScripts — accessed from main and background GCD queues.
    private static let scriptsLock = NSLock()

    /// Returns the current playing song from any supported music application.
    /// Only queries apps that are actually running.
    static func fetchNowPlaying() -> NowPlayingSong? {
        for app in MusicApp.allCases {
            guard isAppRunning(app) else { continue }
            if let song = fetchNowPlaying(from: app) {
                return song
            }
        }
        return nil
    }

    /// Returns the now playing song for a specific music application.
    private static func fetchNowPlaying(from app: MusicApp) -> NowPlayingSong? {
        guard let output = runCompiledAppleScript(app.nowPlayingScript),
            output != "stopped"
        else {
            return nil
        }
        return NowPlayingSong(application: app.rawValue, from: output)
    }

    /// Checks if the specified music application is currently running.
    static func isAppRunning(_ app: MusicApp) -> Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.localizedName == app.rawValue
        }
    }

    /// Executes a pre-compiled AppleScript. Compiles on first use, caches for reuse.
    @discardableResult
    private static func runCompiledAppleScript(_ script: String) -> String? {
        let compiled: NSAppleScript
        scriptsLock.lock()
        if let cached = compiledScripts[script] {
            compiled = cached
            scriptsLock.unlock()
        } else {
            scriptsLock.unlock()
            guard let newScript = NSAppleScript(source: script) else { return nil }
            var compileError: NSDictionary?
            newScript.compileAndReturnError(&compileError)
            if compileError != nil { return nil }
            scriptsLock.lock()
            compiledScripts[script] = newScript
            scriptsLock.unlock()
            compiled = newScript
        }
        var error: NSDictionary?
        let outputDescriptor = compiled.executeAndReturnError(&error)
        if error != nil { return nil }
        return outputDescriptor.stringValue?.trimmingCharacters(
            in: .whitespacesAndNewlines)
    }

    /// Executes an ad-hoc AppleScript (for one-off commands like play/pause).
    @discardableResult
    static func runAppleScript(_ script: String) -> String? {
        runCompiledAppleScript(script)
    }

    /// Returns the first running music application.
    static func activeMusicApp() -> MusicApp? {
        MusicApp.allCases.first { isAppRunning($0) }
    }

    /// Executes a playback command for the active music application.
    static func executeCommand(_ command: (MusicApp) -> String) {
        guard let activeApp = activeMusicApp() else { return }
        _ = runAppleScript(command(activeApp))
    }
}

// MARK: - Now Playing Manager

/// An observable manager that periodically updates the now playing song.
/// Tries MediaRemote (private API) first; dynamically falls back to AppleScript
/// if MediaRemote is unavailable or consistently fails.
final class NowPlayingManager: ObservableObject {
    static let shared = NowPlayingManager()

    @Published private(set) var nowPlaying: NowPlayingSong?
    private var timer: Timer?
    private var consecutiveNilCount = 0
    private let nilThreshold = 10
    private var consecutiveIdleCount = 0
    private var currentInterval: TimeInterval = 1.0

    /// Current provider. Starts with MediaRemote if symbols load, falls back dynamically.
    private var useMediaRemote: Bool = false
    /// Count of consecutive MediaRemote failures while a music app is running.
    private var mrFailWhileMusicRunning = 0
    /// After this many failures with a music app running, switch to AppleScript permanently.
    private let mrFailThreshold = 5
    private var mediaRemoteObservers: [NSObjectProtocol] = []
    /// Grace period: after sending a command, ignore stale state fetches until this time.
    private var commandGraceUntil: Date = .distantPast
    private let logger = AppLogger.shared

    private init() {
        let mr = MediaRemoteProvider.shared
        useMediaRemote = mr._canLoad

        if useMediaRemote {
            mr.registerNotifications()
            setupMediaRemoteObservers()
        }

        // Fetch immediately on init (non-blocking)
        updateNowPlaying()
        scheduleTimer(interval: 1.0)
    }

    deinit {
        timer?.invalidate()
        for obs in mediaRemoteObservers {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    // MARK: - MediaRemote Notifications

    private func setupMediaRemoteObservers() {
        let infoObs = NotificationCenter.default.addObserver(
            forName: .mrNowPlayingInfoDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            self?.fetchViaMediaRemote()
        }
        let playObs = NotificationCenter.default.addObserver(
            forName: .mrNowPlayingIsPlayingDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            self?.fetchViaMediaRemote()
        }
        mediaRemoteObservers = [infoObs, playObs]
    }

    // MARK: - Timer

    private func scheduleTimer(interval: TimeInterval) {
        timer?.invalidate()
        currentInterval = interval
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.updateNowPlaying()
        }
        timer?.tolerance = min(1.0, interval * 0.25)
    }

    // MARK: - Update (dispatch to correct provider)

    private func updateNowPlaying() {
        if useMediaRemote {
            fetchViaMediaRemote()
        } else {
            fetchViaAppleScript()
        }
    }

    // MARK: - MediaRemote Fetch

    private func fetchViaMediaRemote() {
        MediaRemoteProvider.shared.fetchNowPlaying { [weak self] song in
            DispatchQueue.main.async {
                guard let self = self else { return }
                let inGracePeriod = Date() < self.commandGraceUntil

                if let song = song {
                    self.consecutiveNilCount = 0
                    self.mrFailWhileMusicRunning = 0
                    if !inGracePeriod && self.nowPlaying != song {
                        self.nowPlaying = song
                    }
                    let desiredInterval: TimeInterval = song.state == .playing ? 1.0 : 3.0
                    if self.currentInterval != desiredInterval {
                        self.scheduleTimer(interval: desiredInterval)
                    }
                } else {
                    self.consecutiveNilCount += 1

                    // Check if a music app is running but MediaRemote keeps failing
                    let musicRunning = MusicApp.allCases.contains { NowPlayingProvider.isAppRunning($0) }
                    if musicRunning {
                        self.mrFailWhileMusicRunning += 1
                        if self.mrFailWhileMusicRunning >= self.mrFailThreshold {
                            self.useMediaRemote = false
                            self.mrFailWhileMusicRunning = 0
                            self.consecutiveNilCount = 0
                            self.logger.warning("MediaRemote failed repeatedly; switching Now Playing to AppleScript fallback", category: .nowPlaying)
                            self.fetchViaAppleScript()
                            return
                        }
                    }

                    if !inGracePeriod && self.consecutiveNilCount >= self.nilThreshold {
                        self.nowPlaying = nil
                    }
                    if self.currentInterval != 5.0 {
                        self.scheduleTimer(interval: 5.0)
                    }
                }
            }
        }
    }

    // MARK: - AppleScript Fetch (fallback)

    private func fetchViaAppleScript() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let anyMusicAppRunning = MusicApp.allCases.contains { NowPlayingProvider.isAppRunning($0) }

            if !anyMusicAppRunning {
                DispatchQueue.main.async {
                    let inGracePeriod = Date() < self.commandGraceUntil
                    self.consecutiveIdleCount += 1
                    self.consecutiveNilCount += 1
                    if !inGracePeriod && self.consecutiveNilCount >= self.nilThreshold {
                        self.nowPlaying = nil
                    }
                    if self.currentInterval != 5.0 {
                        self.scheduleTimer(interval: 5.0)
                    }
                }
                return
            }

            let song = NowPlayingProvider.fetchNowPlaying()
            DispatchQueue.main.async {
                let inGracePeriod = Date() < self.commandGraceUntil
                self.consecutiveIdleCount = 0
                if let song = song {
                    self.consecutiveNilCount = 0
                    if !inGracePeriod && self.nowPlaying != song {
                        self.nowPlaying = song
                    }
                    let desiredInterval: TimeInterval = song.state == .playing ? 3.0 : 5.0
                    if self.currentInterval != desiredInterval {
                        self.scheduleTimer(interval: desiredInterval)
                    }
                } else {
                    self.consecutiveNilCount += 1
                    if !inGracePeriod && self.consecutiveNilCount >= self.nilThreshold {
                        self.nowPlaying = nil
                    }
                    if self.currentInterval != 5.0 {
                        self.scheduleTimer(interval: 5.0)
                    }
                }
            }
        }
    }

    // MARK: - Playback Controls

    func previousTrack() {
        sendPlaybackCommand {
            if self.useMediaRemote {
                MediaRemoteProvider.shared.sendCommand(.previousTrack)
            } else {
                NowPlayingProvider.executeCommand { $0.previousTrackCommand }
            }
        }
    }

    func togglePlayPause() {
        // Optimistic UI: flip state immediately for instant visual feedback
        if var song = nowPlaying {
            song.state = song.state == .playing ? .paused : .playing
            nowPlaying = song
        }
        sendPlaybackCommand {
            if self.useMediaRemote {
                MediaRemoteProvider.shared.sendCommand(.togglePlayPause)
            } else {
                NowPlayingProvider.executeCommand { $0.togglePlayPauseCommand }
            }
        }
    }

    func nextTrack() {
        sendPlaybackCommand {
            if self.useMediaRemote {
                MediaRemoteProvider.shared.sendCommand(.nextTrack)
            } else {
                NowPlayingProvider.executeCommand { $0.nextTrackCommand }
            }
        }
    }

    /// Sends a playback command with a 1-second grace period that prevents
    /// stale state fetches from overwriting the optimistic UI.
    private func sendPlaybackCommand(_ command: @escaping () -> Void) {
        commandGraceUntil = Date().addingTimeInterval(1.0)
        DispatchQueue.global(qos: .userInitiated).async {
            command()
        }
    }
}
