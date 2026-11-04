import AppKit
import SwiftUI

/// An independent cover component: it shares the native player's metadata and
/// keeps its own size and click target when adjacent track text changes.
struct GlanceMusicArtwork: View {
    let config: ConfigData
    @ObservedObject private var player = NowPlayingManager.shared
    @Environment(\.isBarPreviewRendering) private var preview
    @State private var artwork: NSImage?

    private var previewImage: NSImage? {
        guard preview, let path = ProcessInfo.processInfo.environment["GLANCE_PREVIEW_ARTWORK_PATH"] else { return nil }
        return NSImage(contentsOfFile: path)
    }

    var body: some View {
        let size = min(max(config["music-artwork-size"]?.doubleValue ?? 20, 12), 80)
        Button { MediaRemoteProvider.shared.sendCommand(.togglePlayPause) } label: {
            Image(nsImage: previewImage ?? artwork ?? NSWorkspace.shared.icon(forFile: "/System/Applications/Music.app"))
                .resizable().scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: min(max(config["music-artwork-radius"]?.doubleValue ?? 3, 0), 40)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Album cover, play or pause")
        .task(id: (player.nowPlaying?.id ?? "") + (player.nowPlaying?.albumArtURL?.absoluteString ?? "")) {
            guard !preview else { return }
            artwork = nil
            let song = player.nowPlaying
            var url = song?.albumArtURL
            if url == nil, song != nil {
                let metadata = await withCheckedContinuation { continuation in
                    MediaRemoteProvider.shared.fetchNowPlaying { continuation.resume(returning: $0) }
                }
                if metadata?.title == song?.title { url = metadata?.albumArtURL }
            }
            guard !Task.isCancelled, let url else { return }
            let data: Data?
            if url.isFileURL {
                data = await Task.detached(priority: .utility) { try? Data(contentsOf: url) }.value
            } else if url.scheme == "https" {
                data = try? await URLSession.shared.data(from: url).0
            } else { data = nil }
            guard !Task.isCancelled, let data else { return }
            artwork = NSImage(data: data)
        }
    }
}
