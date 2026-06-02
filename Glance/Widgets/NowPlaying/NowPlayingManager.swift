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

/// Polls `nowplaying-cli` every 5s to detect playback state and fetch metadata.
/// Only updates `nowPlaying` when state or track changes.
final class NowPlayingManager: ObservableObject {
    static let shared = NowPlayingManager()

    @Published private(set) var nowPlaying: NowPlayingSong?

    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.glance.nowplaying", qos: .utility)
    private var lastId: String = ""

    private init() {
        timer = DispatchSource.makeTimerSource(queue: queue)
        timer?.schedule(deadline: .now(), repeating: 5.0, leeway: .seconds(1))
        timer?.setEventHandler { [weak self] in self?.poll() }
        timer?.resume()
    }

    deinit {
        timer?.cancel()
    }

    private func poll() {
        let cliPath = "/opt/homebrew/bin/nowplaying-cli"
        guard FileManager.default.isExecutableFile(atPath: cliPath) else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: cliPath)
        process.arguments = ["get", "--json", "title", "album", "artist", "playbackRate"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        guard (try? process.run()) != nil else { return }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard !data.isEmpty,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        // playbackRate > 0 means playing; 0 means paused/stopped
        let playbackRate = json["playbackRate"] as? Double ?? 0
        let isPlaying = playbackRate > 0
        let title = json["title"] as? String ?? ""
        let album = json["album"] as? String ?? ""
        let artist = json["artist"] as? String ?? ""

        guard isPlaying || !title.isEmpty || !artist.isEmpty else {
            if nowPlaying != nil {
                DispatchQueue.main.async { self.nowPlaying = nil }
            }
            return
        }

        let state: PlaybackState = isPlaying ? .playing : .paused
        let songId = "\(title)|\(artist)|\(state.rawValue)"
        guard songId != lastId else { return }
        lastId = songId

        let song = NowPlayingSong(
            appName: "System Audio",
            state: state,
            title: title,
            artist: artist,
            album: album,
            albumArtURL: nil,
            position: nil,
            duration: nil
        )
        DispatchQueue.main.async { self.nowPlaying = song }
    }
}
