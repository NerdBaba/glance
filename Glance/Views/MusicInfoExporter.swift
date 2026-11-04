import Foundation

/// Read-only diagnostics for the same provider and clock used by the live bar.
@MainActor enum MusicInfoExporter {
    static func export(to url: URL) -> Bool {
        let manager = NowPlayingManager.shared
        let demand = UUID()
        manager.setDemand(demand, enabled: true)
        defer { manager.setDemand(demand, enabled: false) }
        var snapshots: [[String: Any]] = []
        let start = Date()
        for index in 0..<3 {
            RunLoop.main.run(until: start.addingTimeInterval(Double(index * 3 + 3)))
            if let song = manager.nowPlaying {
                snapshots.append(["title": song.title, "artist": song.artist, "album": song.album,
                    "state": song.state.rawValue, "elapsed": song.position as Any? ?? NSNull(),
                    "duration": song.duration as Any? ?? NSNull(), "sampledAt": Date().timeIntervalSince1970])
            }
        }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONSerialization.data(withJSONObject: snapshots, options: [.prettyPrinted, .sortedKeys]).write(to: url)
            return true
        } catch { return false }
    }
}
