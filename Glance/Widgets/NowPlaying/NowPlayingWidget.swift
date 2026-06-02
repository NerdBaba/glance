import SwiftUI

// MARK: - Now Playing Widget

struct NowPlayingWidget: View {
    @EnvironmentObject var configProvider: ConfigProvider
    @StateObject private var playingManager = NowPlayingManager.shared

    @State private var widgetFrame: CGRect = .zero
    @State private var animatedWidth: CGFloat = 0

    var body: some View {
        ZStack {
            if let song = playingManager.nowPlaying {
                MeasurableNowPlayingContent(
                    song: song,
                    showIcon: showIcon,
                    showTitle: showTitle,
                    showArtist: showArtist,
                    showAlbum: showAlbum,
                    titleMaxLength: titleMaxLength,
                    artistMaxLength: artistMaxLength,
                    albumMaxLength: albumMaxLength,
                    separator: separator,
                    showVisualizer: showVisualizer,
                    visualizerPosition: visualizerPosition
                ) { measuredWidth in
                    if animatedWidth == 0 {
                        animatedWidth = measuredWidth
                    } else if animatedWidth != measuredWidth {
                        withAnimation(.smooth) {
                            animatedWidth = measuredWidth
                        }
                    }
                }
                .hidden()

                VisibleNowPlayingContent(
                    song: song,
                    width: animatedWidth,
                    showIcon: showIcon,
                    showTitle: showTitle,
                    showArtist: showArtist,
                    showAlbum: showAlbum,
                    titleMaxLength: titleMaxLength,
                    artistMaxLength: artistMaxLength,
                    albumMaxLength: albumMaxLength,
                    separator: separator,
                    showVisualizer: showVisualizer,
                    visualizerPosition: visualizerPosition
                )
                    .onTapGesture {
                        MenuBarPopup.show(rect: widgetFrame, id: "nowplaying") {
                            NowPlayingPopup()
                        }
                    }
            }
        }
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear { widgetFrame = geometry.frame(in: .global) }
            }
        )
    }

    private var showIcon: Bool { configProvider.config["show-icon"]?.boolValue ?? true }
    private var showTitle: Bool { configProvider.config["show-title"]?.boolValue ?? true }
    private var showArtist: Bool { configProvider.config["show-artist"]?.boolValue ?? false }
    private var showAlbum: Bool { configProvider.config["show-album"]?.boolValue ?? false }
    private var titleMaxLength: Int { configProvider.config["title-max-length"]?.intValue ?? 30 }
    private var artistMaxLength: Int { configProvider.config["artist-max-length"]?.intValue ?? 20 }
    private var albumMaxLength: Int { configProvider.config["album-max-length"]?.intValue ?? 20 }
    private var separator: String { configProvider.config["separator"]?.stringValue ?? " - " }
    private var showVisualizer: Bool { configProvider.config["show-visualizer"]?.boolValue ?? true }
    private var visualizerPosition: VisualizerPosition {
        let raw = configProvider.config["visualizer-position"]?.stringValue ?? "right"
        return VisualizerPosition(rawValue: raw) ?? .right
    }
}

// MARK: - Music Icon View

struct MusicIconView: View {
    @StateObject private var manager = NowPlayingManager.shared

    private var isPlaying: Bool { manager.nowPlaying?.state == .playing }

    var body: some View {
        Image(systemName: "music.note")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(isPlaying ? Color.white.opacity(0.9) : Color.white.opacity(0.3))
    }
}

// MARK: - Now Playing Content

struct NowPlayingContent: View {
    let song: NowPlayingSong
    let showIcon: Bool
    let showTitle: Bool
    let showArtist: Bool
    let showAlbum: Bool
    let titleMaxLength: Int
    let artistMaxLength: Int
    let albumMaxLength: Int
    let separator: String
    let showVisualizer: Bool
    let visualizerPosition: VisualizerPosition

    @Environment(\.widgetFont) var widgetFont
    @Environment(\.appearance) var appearance

    var body: some View {
        HStack(spacing: 5) {
            if visualizerPosition == .left && showVisualizer {
                visualizer
            }

            if showIcon {
                MusicIconView()
            }

            if visualizerPosition == .afterIcon && showVisualizer {
                visualizer
            }

            let parts = textParts
            if !parts.isEmpty {
                Text(parts.joined(separator: separator))
                    .font(widgetFont.toFont())
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            if visualizerPosition == .right && showVisualizer {
                visualizer
            }
        }
        .padding(.horizontal, 4)
    }

    private var visualizer: some View {
        AudioVisualizerView(
            isPlaying: song.state == .playing,
            barCount: 5,
            color: appearance.accentColor
        )
    }

    private var textParts: [String] {
        var parts: [String] = []

        if showTitle, !song.title.isEmpty {
            parts.append(truncate(song.title, max: titleMaxLength))
        }
        if showArtist, !song.artist.isEmpty {
            parts.append(truncate(song.artist, max: artistMaxLength))
        }
        if showAlbum, !song.album.isEmpty {
            parts.append(truncate(song.album, max: albumMaxLength))
        }

        return parts
    }

    private func truncate(_ text: String, max maxLength: Int) -> String {
        if text.count > maxLength {
            let endIndex = text.index(text.startIndex, offsetBy: maxLength)
            return String(text[..<endIndex]) + "..."
        }
        return text
    }
}

// MARK: - Measurable / Visible wrappers

struct MeasurableNowPlayingContent: View {
    let song: NowPlayingSong
    let showIcon: Bool
    let showTitle: Bool
    let showArtist: Bool
    let showAlbum: Bool
    let titleMaxLength: Int
    let artistMaxLength: Int
    let albumMaxLength: Int
    let separator: String
    let showVisualizer: Bool
    let visualizerPosition: VisualizerPosition
    let onSizeChange: (CGFloat) -> Void

    var body: some View {
        NowPlayingContent(
            song: song,
            showIcon: showIcon,
            showTitle: showTitle,
            showArtist: showArtist,
            showAlbum: showAlbum,
            titleMaxLength: titleMaxLength,
            artistMaxLength: artistMaxLength,
            albumMaxLength: albumMaxLength,
            separator: separator,
            showVisualizer: showVisualizer,
            visualizerPosition: visualizerPosition
        )
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear { onSizeChange(geometry.size.width) }
                    .onChange(of: geometry.size.width) { _, newWidth in
                        onSizeChange(newWidth)
                    }
            }
        )
    }
}

struct VisibleNowPlayingContent: View {
    let song: NowPlayingSong
    let width: CGFloat
    let showIcon: Bool
    let showTitle: Bool
    let showArtist: Bool
    let showAlbum: Bool
    let titleMaxLength: Int
    let artistMaxLength: Int
    let albumMaxLength: Int
    let separator: String
    let showVisualizer: Bool
    let visualizerPosition: VisualizerPosition

    var body: some View {
        NowPlayingContent(
            song: song,
            showIcon: showIcon,
            showTitle: showTitle,
            showArtist: showArtist,
            showAlbum: showAlbum,
            titleMaxLength: titleMaxLength,
            artistMaxLength: artistMaxLength,
            albumMaxLength: albumMaxLength,
            separator: separator,
            showVisualizer: showVisualizer,
            visualizerPosition: visualizerPosition
        )
        .frame(width: width)
        .animation(.smooth(duration: 0.1), value: song)
        .transition(.blurReplace)
    }
}

// MARK: - Preview

struct NowPlayingWidget_Previews: PreviewProvider {
    static var previews: some View {
        ZStack { NowPlayingWidget() }.frame(width: 500, height: 100)
    }
}
