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
                MeasurableNowPlayingContent(song: song, showIcon: showIcon, showTitle: showTitle, titleMaxLength: titleMaxLength) { measuredWidth in
                    if animatedWidth == 0 {
                        animatedWidth = measuredWidth
                    } else if animatedWidth != measuredWidth {
                        withAnimation(.smooth) {
                            animatedWidth = measuredWidth
                        }
                    }
                }
                .hidden()

                VisibleNowPlayingContent(song: song, width: animatedWidth, showIcon: showIcon, showTitle: showTitle, titleMaxLength: titleMaxLength)
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
    private var titleMaxLength: Int { configProvider.config["title-max-length"]?.intValue ?? 30 }
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
    let titleMaxLength: Int

    @Environment(\.widgetFont) var widgetFont

    var body: some View {
        HStack(spacing: 5) {
            if showIcon {
                MusicIconView()
            }
            if showTitle, !song.title.isEmpty {
                Text(truncatedTitle)
                    .font(widgetFont.toFont())
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(.horizontal, 4)
    }

    private var truncatedTitle: String {
        let title = song.title
        if title.count > titleMaxLength {
            let endIndex = title.index(title.startIndex, offsetBy: titleMaxLength)
            return String(title[..<endIndex]) + "..."
        }
        return title
    }
}

// MARK: - Measurable / Visible wrappers

struct MeasurableNowPlayingContent: View {
    let song: NowPlayingSong
    let showIcon: Bool
    let showTitle: Bool
    let titleMaxLength: Int
    let onSizeChange: (CGFloat) -> Void

    var body: some View {
        NowPlayingContent(song: song, showIcon: showIcon, showTitle: showTitle, titleMaxLength: titleMaxLength)
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
    let titleMaxLength: Int

    var body: some View {
        NowPlayingContent(song: song, showIcon: showIcon, showTitle: showTitle, titleMaxLength: titleMaxLength)
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
