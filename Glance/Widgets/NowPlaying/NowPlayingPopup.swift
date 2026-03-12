import SwiftUI

struct NowPlayingPopup: View {
    @ObservedObject var configProvider: ConfigProvider
    @ObservedObject private var playingManager = NowPlayingManager.shared
    @ObservedObject var configManager = ConfigManager.shared
    var appearance: AppearanceConfig { configManager.config.appearance }

    var body: some View {
        Group {
            if let song = playingManager.nowPlaying {
                VStack(spacing: 0) {
                    albumArt(for: song)
                        .padding(.bottom, 16)

                    VStack(spacing: 6) {
                        Text(song.title)
                            .font(.system(size: 15, weight: .semibold))
                            .lineLimit(1)

                        Text(song.artist)
                            .font(.system(size: 13))
                            .opacity(0.6)
                            .lineLimit(1)

                        if !song.album.isEmpty {
                            Text(song.album)
                                .font(.system(size: 12))
                                .opacity(0.4)
                                .lineLimit(1)
                        }

                        Text(song.appName)
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(appearance.foregroundColor.opacity(0.08))
                            .clipShape(Capsule())
                            .padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 14)

                    if let duration = song.duration, let position = song.position {
                        PlaybackProgressSection(
                            song: song,
                            position: position,
                            duration: duration,
                            accentColor: appearance.accentColor,
                            trackColor: appearance.foregroundColor.opacity(0.15)
                        )
                        .padding(.bottom, 16)
                    }

                    HStack(spacing: 36) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 16))
                            .opacity(0.7)
                            .onTapGesture { playingManager.previousTrack() }
                        Image(systemName: song.state == .paused ? "play.fill" : "pause.fill")
                            .font(.system(size: 24))
                            .onTapGesture { playingManager.togglePlayPause() }
                        Image(systemName: "forward.fill")
                            .font(.system(size: 16))
                            .opacity(0.7)
                            .onTapGesture { playingManager.nextTrack() }
                    }
                }
                .animation(.easeInOut, value: song.albumArtURL)
            } else {
                EmptyNowPlayingState(appearance: appearance)
            }
        }
        .padding(22)
        .frame(width: 264)
    }

    @ViewBuilder
    private func albumArt(for song: NowPlayingSong) -> some View {
        RotateAnimatedCachedImage(
            url: song.albumArtURL,
            targetSize: CGSize(width: 400, height: 400)
        ) { image in
            image.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .frame(width: 220, height: 220)
        .overlay {
            if song.albumArtURL == nil {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(appearance.foregroundColor.opacity(0.08))
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: 44))
                            .foregroundStyle(appearance.accentColor.opacity(0.75))
                    }
            }
        }
        .scaleEffect(song.state == .paused ? 0.95 : 1)
        .opacity(song.state == .paused ? 0.7 : 1)
        .animation(.smooth(duration: 0.4), value: song.state == .paused)
    }
}

// MARK: - Smooth Progress Bar

/// A progress bar that smoothly animates between position updates.
private struct SmoothProgressBar: View {
    let position: Double
    let duration: Double
    let isPlaying: Bool
    let accentColor: Color
    let trackColor: Color

    @State private var animatedProgress: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 2)
                    .fill(trackColor)
                    .frame(height: 3)

                // Fill
                RoundedRectangle(cornerRadius: 2)
                    .fill(accentColor)
                    .frame(width: geo.size.width * animatedProgress, height: 3)

                // Knob
                Circle()
                    .fill(accentColor)
                    .frame(width: 8, height: 8)
                    .offset(x: max(0, geo.size.width * animatedProgress - 4))
                    .shadow(color: accentColor.opacity(0.4), radius: 4)
            }
        }
        .frame(height: 8)
        .onAppear {
            animatedProgress = CGFloat(position / max(duration, 1))
        }
        .onChange(of: position) { _, newPosition in
            withAnimation(.linear(duration: isPlaying ? 0.3 : 0)) {
                animatedProgress = CGFloat(newPosition / max(duration, 1))
            }
        }
    }
}

private struct PlaybackProgressSection: View {
    let song: NowPlayingSong
    let position: Double
    let duration: Double
    let accentColor: Color
    let trackColor: Color

    @State private var basePosition: Double
    @State private var baseDate: Date

    init(song: NowPlayingSong, position: Double, duration: Double, accentColor: Color, trackColor: Color) {
        self.song = song
        self.position = position
        self.duration = duration
        self.accentColor = accentColor
        self.trackColor = trackColor
        _basePosition = State(initialValue: position)
        _baseDate = State(initialValue: Date())
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let livePosition = currentPosition(at: context.date)

            VStack(spacing: 4) {
                SmoothProgressBar(
                    position: livePosition,
                    duration: duration,
                    isPlaying: song.state == .playing,
                    accentColor: accentColor,
                    trackColor: trackColor
                )

                HStack {
                    Text(timeString(from: livePosition))
                    Spacer()
                    Text("-" + timeString(from: max(duration - livePosition, 0)))
                }
                .font(.caption2)
                .monospacedDigit()
                .opacity(0.4)
            }
        }
        .onAppear {
            syncBaseState(position: position)
        }
        .onChange(of: position) { _, newPosition in
            syncBaseState(position: newPosition)
        }
        .onChange(of: song.state) { _, _ in
            syncBaseState(position: position)
        }
        .onChange(of: song.id) { _, _ in
            syncBaseState(position: position)
        }
    }

    private func syncBaseState(position: Double) {
        basePosition = position
        baseDate = Date()
    }

    private func currentPosition(at date: Date) -> Double {
        guard song.state == .playing else { return min(basePosition, duration) }
        let elapsed = date.timeIntervalSince(baseDate)
        return min(basePosition + elapsed, duration)
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
            Text("Start playback to see artwork, progress, and controls here.")
                .font(.system(size: 11))
                .opacity(0.5)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 18)
    }
}

private func timeString(from seconds: Double) -> String {
    let intSeconds = Int(seconds)
    let minutes = intSeconds / 60
    let remainingSeconds = intSeconds % 60
    return String(format: "%d:%02d", minutes, remainingSeconds)
}
