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
    let state: PlaybackState
    let title: String
    let artist: String
    let album: String
    let albumArtURL: URL?
    let position: Double?
    let duration: Double?  // Duration in seconds

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
        if let cached = compiledScripts[script] {
            compiled = cached
        } else {
            guard let newScript = NSAppleScript(source: script) else { return nil }
            var compileError: NSDictionary?
            newScript.compileAndReturnError(&compileError)
            if compileError != nil { return nil }
            compiledScripts[script] = newScript
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
final class NowPlayingManager: ObservableObject {
    static let shared = NowPlayingManager()

    @Published private(set) var nowPlaying: NowPlayingSong?
    private var timer: Timer?
    private var consecutiveNilCount = 0
    /// Number of consecutive nil responses before clearing the widget.
    private let nilThreshold = 10
    /// Consecutive idle polls (no music app running) before slowing down.
    private var consecutiveIdleCount = 0

    /// Polling interval: 1s when playing, 3s when paused/stopped, 5s when no music app running.
    private var currentInterval: TimeInterval = 1.0

    private init() {
        scheduleTimer(interval: 1.0)
    }

    deinit {
        timer?.invalidate()
    }

    private func scheduleTimer(interval: TimeInterval) {
        timer?.invalidate()
        currentInterval = interval
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.updateNowPlaying()
        }
        // Fire immediately on first schedule
        updateNowPlaying()
    }

    /// Updates the now playing song asynchronously.
    private func updateNowPlaying() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }

            // Fast check: is any music app even running?
            let anyMusicAppRunning = MusicApp.allCases.contains { NowPlayingProvider.isAppRunning($0) }

            if !anyMusicAppRunning {
                DispatchQueue.main.async {
                    self.consecutiveIdleCount += 1
                    self.consecutiveNilCount += 1
                    if self.consecutiveNilCount >= self.nilThreshold {
                        self.nowPlaying = nil
                    }
                    // Slow down to 5s when no music app is running
                    let desiredInterval: TimeInterval = 5.0
                    if self.currentInterval != desiredInterval {
                        self.scheduleTimer(interval: desiredInterval)
                    }
                }
                return
            }

            let song = NowPlayingProvider.fetchNowPlaying()
            DispatchQueue.main.async {
                self.consecutiveIdleCount = 0
                if let song = song {
                    self.consecutiveNilCount = 0
                    // Only publish if song data actually changed
                    if self.nowPlaying != song {
                        self.nowPlaying = song
                    }
                    // 3s when playing, 5s when paused — AppleScript IPC is expensive
                    let desiredInterval: TimeInterval = song.state == .playing ? 3.0 : 5.0
                    if self.currentInterval != desiredInterval {
                        self.scheduleTimer(interval: desiredInterval)
                    }
                } else {
                    self.consecutiveNilCount += 1
                    if self.consecutiveNilCount >= self.nilThreshold {
                        self.nowPlaying = nil
                    }
                    // Music app running but nothing playing — 5s
                    let desiredInterval: TimeInterval = 5.0
                    if self.currentInterval != desiredInterval {
                        self.scheduleTimer(interval: desiredInterval)
                    }
                }
            }
        }
    }

    /// Skips to the previous track.
    func previousTrack() {
        NowPlayingProvider.executeCommand { $0.previousTrackCommand }
    }

    /// Toggles between play and pause.
    func togglePlayPause() {
        NowPlayingProvider.executeCommand { $0.togglePlayPauseCommand }
    }

    /// Skips to the next track.
    func nextTrack() {
        NowPlayingProvider.executeCommand { $0.nextTrackCommand }
    }
}
