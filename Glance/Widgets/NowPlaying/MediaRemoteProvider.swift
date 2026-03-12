import Foundation

// MARK: - MediaRemote Command Constants

enum MRCommand: UInt32 {
    case play = 0
    case pause = 1
    case togglePlayPause = 2
    case stop = 3
    case nextTrack = 4
    case previousTrack = 5
}

// MARK: - MediaRemote Info Keys

private let kTitle = "kMRMediaRemoteNowPlayingInfoTitle"
private let kArtist = "kMRMediaRemoteNowPlayingInfoArtist"
private let kAlbum = "kMRMediaRemoteNowPlayingInfoAlbum"
private let kDuration = "kMRMediaRemoteNowPlayingInfoDuration"
private let kElapsedTime = "kMRMediaRemoteNowPlayingInfoElapsedTime"
private let kArtworkData = "kMRMediaRemoteNowPlayingInfoArtworkData"
private let kPlaybackRate = "kMRMediaRemoteNowPlayingInfoPlaybackRate"

// MARK: - Notification Names

extension Notification.Name {
    static let mrNowPlayingInfoDidChange = Notification.Name(
        "kMRMediaRemoteNowPlayingInfoDidChangeNotification")
    static let mrNowPlayingIsPlayingDidChange = Notification.Name(
        "kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification")
}

// MARK: - MediaRemote Function Types

private typealias MRGetNowPlayingInfoFn = @convention(c) (
    DispatchQueue, @escaping @convention(block) (CFDictionary?) -> Void
) -> Void

private typealias MRRegisterNotificationsFn = @convention(c) (DispatchQueue) -> Void

private typealias MRSendCommandFn = @convention(c) (UInt32, NSDictionary?) -> Bool

// MARK: - MediaRemote Provider

final class MediaRemoteProvider {
    static let shared = MediaRemoteProvider()

    private(set) var isAvailable = false
    /// Whether the framework symbols loaded (dlopen + dlsym succeeded).
    let _canLoad: Bool
    private var registered = false

    private let _getNowPlayingInfo: MRGetNowPlayingInfoFn?
    private let _registerNotifications: MRRegisterNotificationsFn?
    private let _sendCommand: MRSendCommandFn?

    private init() {
        guard let handle = dlopen(
            "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote",
            RTLD_LAZY
        ) else {
            _getNowPlayingInfo = nil
            _registerNotifications = nil
            _sendCommand = nil
            _canLoad = false
            return
        }

        if let sym = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") {
            _getNowPlayingInfo = unsafeBitCast(sym, to: MRGetNowPlayingInfoFn.self)
        } else {
            _getNowPlayingInfo = nil
        }

        if let sym = dlsym(handle, "MRMediaRemoteRegisterForNowPlayingNotifications") {
            _registerNotifications = unsafeBitCast(sym, to: MRRegisterNotificationsFn.self)
        } else {
            _registerNotifications = nil
        }

        if let sym = dlsym(handle, "MRMediaRemoteSendCommand") {
            _sendCommand = unsafeBitCast(sym, to: MRSendCommandFn.self)
        } else {
            _sendCommand = nil
        }

        _canLoad = _getNowPlayingInfo != nil

        // No blocking testAvailability() here — assume available if symbols loaded.
        // Dynamic fallback in NowPlayingManager handles failures at runtime.
        isAvailable = _canLoad
    }

    func registerNotifications() {
        guard !registered, let register = _registerNotifications else { return }
        registered = true
        register(DispatchQueue.main)
    }

    func fetchNowPlaying(completion: @escaping (NowPlayingSong?) -> Void) {
        guard let getInfo = _getNowPlayingInfo else {
            completion(nil)
            return
        }

        getInfo(DispatchQueue.global(qos: .userInitiated)) { info in
            guard let dict = info as? [String: Any] else {
                completion(nil)
                return
            }

            guard let title = dict[kTitle] as? String, !title.isEmpty else {
                completion(nil)
                return
            }

            let artist = dict[kArtist] as? String ?? ""
            let album = dict[kAlbum] as? String ?? ""
            let duration = dict[kDuration] as? Double
            let elapsed = dict[kElapsedTime] as? Double
            let playbackRate = dict[kPlaybackRate] as? Double ?? 0

            let state: PlaybackState = playbackRate > 0 ? .playing : .paused

            var artworkURL: URL? = nil
            if let artData = dict[kArtworkData] as? Data, !artData.isEmpty {
                let tmpPath = NSTemporaryDirectory() + "glance_artwork_\(title.hashValue).jpg"
                try? artData.write(to: URL(fileURLWithPath: tmpPath))
                artworkURL = URL(fileURLWithPath: tmpPath)
            }

            let song = NowPlayingSong(
                appName: "MediaRemote",
                state: state,
                title: title,
                artist: artist,
                album: album,
                albumArtURL: artworkURL,
                position: elapsed,
                duration: duration
            )
            completion(song)
        }
    }

    func sendCommand(_ command: MRCommand) {
        _ = _sendCommand?(command.rawValue, nil)
    }
}
