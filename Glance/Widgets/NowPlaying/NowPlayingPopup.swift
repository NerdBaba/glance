import SwiftUI

struct NowPlayingPopup: View {
    @ObservedObject private var playingManager = NowPlayingManager.shared
    @State private var demand = UUID()
    @ObservedObject var configManager = ConfigManager.shared
    var appearance: AppearanceConfig { configManager.config.appearance }

    var body: some View {
        Group {
            if let song = playingManager.nowPlaying, song.state != .stopped {
                VStack(spacing: 12) {
                    Image(systemName: "speaker.wave.3")
                        .font(.system(size: 36))
                        .foregroundStyle(appearance.accentColor.opacity(0.8))
                    Text(song.title.isEmpty ? "System Audio Playing" : song.title)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(2)
                    if !song.artist.isEmpty {
                        Text(song.artist)
                            .font(.system(size: 14))
                            .opacity(0.6)
                            .lineLimit(1)
                    }
                    if !song.album.isEmpty {
                        Text(song.album).font(.system(size: 14)).opacity(0.7).lineLimit(2)
                    }
                    if song.position != nil || song.duration != nil {
                        Text(GlanceMusicFormatting.time(song.position) + " / " + GlanceMusicFormatting.time(song.duration))
                            .font(.system(size: 14, design: .monospaced)).monospacedDigit()
                    }
                    if let position = song.position, let duration = song.duration, duration > 0 {
                        ProgressView(value: min(position, duration), total: duration).tint(appearance.accentColor)
                    }
                    Text("Playing through your default output device.")
                        .font(.system(size: 11))
                        .opacity(0.5)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 18)
            } else {
                EmptyNowPlayingState(appearance: appearance)
            }
        }
        .padding(22)
        .frame(width: 264)
        .onAppear { playingManager.setDemand(demand, enabled: true) }
        .onDisappear { playingManager.setDemand(demand, enabled: false) }
    }
}

private struct EmptyNowPlayingState: View {
    let appearance: AppearanceConfig

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "music.note")
                .font(.system(size: 30))
                .foregroundStyle(appearance.accentColor.opacity(0.8))
            Text("Nothing playing")
                .font(.system(size: 14, weight: .semibold))
            Text("Start playback to see info here.")
                .font(.system(size: 11))
                .opacity(0.5)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 18)
    }
}
