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
    var position: Double?
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

/// Refreshes metadata every five seconds and advances the reported playback
/// position locally each second. Pauses and seeks replace the clock anchor.
final class NowPlayingManager: ObservableObject {
    static let shared = NowPlayingManager()

    @Published private(set) var nowPlaying: NowPlayingSong?

    private let scheduleID = UUID()
    private var consumers: [UUID: Bool] = [:]
    private var demandGeneration = 0
    private var wakeObserver: NSObjectProtocol?
    private let queue = DispatchQueue(label: "com.glance.nowplaying", qos: .utility)
    private let clockScheduleID = UUID()
    private var clockRunning = false
    private var anchor: NowPlayingSong?
    private var anchorUptime: TimeInterval = 0
    private var playbackRate: Double = 0
    private var artworkTrack: String?
    private var artworkURL: URL?
    // Polling runs on one serial queue, so these cached paths need no lock.
    private var resolvedAdapter: (script: String, library: String)?
    private var resolvedCLI: String?

    private init() {
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.refresh() }
    }

    deinit {
        let id = scheduleID
        let clockID = clockScheduleID
        let cancel = {
            WidgetUpdateScheduler.shared.cancel(id)
            WidgetUpdateScheduler.shared.cancel(clockID)
        }
        if Thread.isMainThread { cancel() }
        else { DispatchQueue.main.async(execute: cancel) }
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
    }

    func setDemand(_ id: UUID, enabled: Bool, elapsed: Bool = true) {
        precondition(Thread.isMainThread)
        let wasActive = !consumers.isEmpty
        if enabled { consumers[id] = elapsed } else { consumers.removeValue(forKey: id) }
        guard wasActive != !consumers.isEmpty else {
            setClockEnabled(nowPlaying?.state == .playing)
            return
        }
        demandGeneration += 1
        if consumers.isEmpty {
            WidgetUpdateScheduler.shared.cancel(scheduleID)
            setClockEnabled(false)
        } else {
            WidgetUpdateScheduler.shared.schedule(scheduleID, every: 5) { [weak self] in self?.refresh() }
            refresh()
        }
    }

    private func refresh() {
        guard !consumers.isEmpty else { return }
        let generation = demandGeneration
        queue.async { [weak self] in self?.poll(generation: generation) }
    }

    private func poll(generation: Int) {
        // The installed adapter retains the timeline timestamp. The CLI's
        // elapsedTime conversion loses that anchor on recent macOS versions.
        var json: [String: Any]?
        // Homebrew upgrades can remove a previously resolved Cellar path.
        // Discard it before resolution so the preferred timestamp-aware
        // backend can recover without restarting Glance.
        if let adapter = resolvedAdapter,
           !FileManager.default.isReadableFile(atPath: adapter.script)
            || !FileManager.default.isReadableFile(atPath: adapter.library) {
            resolvedAdapter = nil
        }
        if resolvedAdapter == nil {
            resolvedAdapter = Self.helperRoots.compactMap { root -> (script: String, library: String)? in
                let cli = URL(fileURLWithPath: root + "/bin/nowplaying-cli").resolvingSymlinksInPath()
                let base = cli.deletingLastPathComponent().deletingLastPathComponent().path
                let script = base + "/share/nowplaying-cli/scripts/mediaremote-mini.pl"
                let library = base + "/lib/nowplaying-cli/MediaRemoteMini.dylib"
                return FileManager.default.isReadableFile(atPath: script) && FileManager.default.isReadableFile(atPath: library)
                    ? (script, library) : nil
            }.first
        }
        if let adapter = resolvedAdapter,
           FileManager.default.isReadableFile(atPath: adapter.script),
           FileManager.default.isReadableFile(atPath: adapter.library) {
            json = readJSON(executable: "/usr/bin/perl", arguments: [adapter.script, adapter.library, "adapter_get_env"])
        }
        if json == nil {
            let cli = resolveCLI()
            if let cli {
                json = readJSON(executable: cli, arguments: ["get", "--json", "title", "album", "artist", "playbackRate", "elapsedTime", "duration", "timestamp"])
            }
        }
        guard let json else { return }

        // playbackRate > 0 means playing; 0 means paused/stopped
        let playbackRate = Self.number(json["playbackRate"]) ?? ((json["playing"] as? Bool == true) ? 1 : 0)
        let isPlaying = playbackRate > 0
        let title = json["title"] as? String ?? ""
        let album = json["album"] as? String ?? ""
        let artist = json["artist"] as? String ?? ""

        let artworkID = title + "\n" + artist + "\n" + album
        if artworkID != artworkTrack {
            artworkTrack = artworkID
            if let oldURL = artworkURL { try? FileManager.default.removeItem(at: oldURL) }
            artworkURL = nil
            var encoded = json["artworkData"] as? String
            if encoded == nil, !title.isEmpty {
                if let cli = resolveCLI() {
                    encoded = readJSON(executable: cli, arguments: ["get", "--json", "artworkData"])?["artworkData"] as? String
                }
            }
            if let encoded, let data = Data(base64Encoded: encoded), !data.isEmpty, data.count <= 20_000_000 {
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("glance-cover-" + UUID().uuidString)
                if (try? data.write(to: url, options: .atomic)) != nil { artworkURL = url }
            }
        }

        guard isPlaying || !title.isEmpty || !artist.isEmpty else {
            DispatchQueue.main.async {
                guard generation == self.demandGeneration, !self.consumers.isEmpty else { return }
                self.anchor = nil
                self.nowPlaying = nil
                self.setClockEnabled(false)
            }
            return
        }

        let state: PlaybackState = isPlaying ? .playing : .paused
        let duration = Self.number(json["duration"]).flatMap { $0 > 0 ? $0 : nil }
        var position = Self.number(json["elapsedTime"]).flatMap { $0 >= 0 ? $0 : nil }
        if isPlaying, let timestamp = Self.timestamp(json["timestamp"]), let reported = position {
            position = reported + max(0, Date().timeIntervalSince(timestamp)) * playbackRate
        }
        if let elapsed = position, let duration { position = min(elapsed, duration) }

        let song = NowPlayingSong(
            appName: "System Audio",
            state: state,
            title: title,
            artist: artist,
            album: album,
            albumArtURL: artworkURL,
            position: position,
            duration: duration
        )
        DispatchQueue.main.async {
            guard generation == self.demandGeneration, !self.consumers.isEmpty else { return }
            self.anchor = song
            self.anchorUptime = ProcessInfo.processInfo.systemUptime
            self.playbackRate = playbackRate
            if self.nowPlaying != song { self.nowPlaying = song }
            self.setClockEnabled(isPlaying)
        }
    }

    private static let helperRoots = ["/opt/homebrew", "/usr/local"]

    private func resolveCLI() -> String? {
        if let cli = resolvedCLI, FileManager.default.isExecutableFile(atPath: cli) { return cli }
        resolvedCLI = Self.helperRoots.map { $0 + "/bin/nowplaying-cli" }
            .first(where: { FileManager.default.isExecutableFile(atPath: $0) })
        return resolvedCLI
    }

    private func setClockEnabled(_ enabled: Bool) {
        let shouldRun = enabled && consumers.values.contains(true)
        guard shouldRun != clockRunning else { return }
        clockRunning = shouldRun
        if shouldRun {
            WidgetUpdateScheduler.shared.schedule(clockScheduleID, every: 1) { [weak self] in self?.advanceClock() }
        } else {
            WidgetUpdateScheduler.shared.cancel(clockScheduleID)
        }
    }

    private func advanceClock() {
        guard var song = anchor, song.state == .playing, let position = song.position else { return }
        let elapsed = position + max(0, ProcessInfo.processInfo.systemUptime - anchorUptime) * playbackRate
        song.position = song.duration.map { min(elapsed, $0) } ?? elapsed
        if nowPlaying != song { nowPlaying = song }
    }

    private static func number(_ value: Any?) -> Double? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        let result = number.doubleValue
        return result.isFinite ? result : nil
    }

    private static func timestamp(_ value: Any?) -> Date? {
        if let seconds = number(value), seconds > 0 { return Date(timeIntervalSince1970: seconds) }
        guard let text = value as? String else { return nil }
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: text) { return date }
        formatter.formatOptions.insert(.withFractionalSeconds)
        return formatter.date(from: text)
    }

    private func readJSON(executable: String, arguments: [String]) -> [String: Any]? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        let timeout = DispatchWorkItem { if process.isRunning { process.terminate() } }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 4, execute: timeout)
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        timeout.cancel()
        guard process.terminationStatus == 0, !data.isEmpty else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
}
