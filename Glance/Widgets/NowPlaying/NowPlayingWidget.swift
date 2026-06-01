import SwiftUI

// MARK: - Now Playing Widget

struct NowPlayingWidget: View {
    @EnvironmentObject var configProvider: ConfigProvider
    @ObservedObject var playingManager = NowPlayingManager.shared

    @State private var widgetFrame: CGRect = .zero
    @State private var animatedWidth: CGFloat = 0

    var body: some View {
        ZStack {
            if let song = playingManager.nowPlaying {
                MeasurableNowPlayingContent(song: song, showCava: showCava, showTitle: showTitle, barCount: barCount, barWidth: barWidth, barGap: barGap, barHeight: barHeight) { measuredWidth in
                    if animatedWidth == 0 {
                        animatedWidth = measuredWidth
                    } else if animatedWidth != measuredWidth {
                        withAnimation(.smooth) {
                            animatedWidth = measuredWidth
                        }
                    }
                }
                .hidden()

                VisibleNowPlayingContent(song: song, width: animatedWidth, showCava: showCava, showTitle: showTitle, barCount: barCount, barWidth: barWidth, barGap: barGap, barHeight: barHeight)
                    .onTapGesture {
                        MenuBarPopup.show(rect: widgetFrame, id: "nowplaying") {
                            NowPlayingPopup()
                        }
                    }
            }
        }
        .drawingGroup()
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear { widgetFrame = geometry.frame(in: .global) }
            }
        )
    }

    private var showCava: Bool { configProvider.config["show-cava"]?.boolValue ?? true }
    private var showTitle: Bool { configProvider.config["show-title"]?.boolValue ?? true }
    private var barCount: Int { configProvider.config["bar-count"]?.intValue ?? 12 }
    private var barWidth: CGFloat { CGFloat(configProvider.config["bar-width"]?.intValue ?? 2) }
    private var barGap: CGFloat { CGFloat(configProvider.config["bar-gap"]?.intValue ?? 2) }
    private var barHeight: CGFloat { CGFloat(configProvider.config["bar-height"]?.intValue ?? 16) }
}

// MARK: - Cava Bars View (TimelineView-based, no @State timers)

struct CavaBarsView: View {
    let isPlaying: Bool
    let barCount: Int
    let barWidth: CGFloat
    let barGap: CGFloat
    let barHeight: CGFloat

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.2)) { timeline in
            HStack(spacing: barGap) {
                ForEach(0..<barCount, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(isPlaying ? Color.primary.opacity(0.8) : Color.primary.opacity(0.2))
                        .frame(width: barWidth, height: isPlaying ? barHeight(at: timeline.date, index: index) : 1)
                }
            }
            .frame(height: barHeight)
            .animation(.easeInOut(duration: 0.2), value: isPlaying)
        }
    }

    private func barHeight(at date: Date, index: Int) -> CGFloat {
        let t = Int(CFAbsoluteTimeGetCurrent() * 5)
        let v = abs((index * 31 + t * 17).hashValue)
        return CGFloat(v % 1000) / 1000.0 * (barHeight - 2) + 2
    }
}

// MARK: - Now Playing Content

struct NowPlayingContent: View {
    let song: NowPlayingSong
    let showCava: Bool
    let showTitle: Bool
    let barCount: Int
    let barWidth: CGFloat
    let barGap: CGFloat
    let barHeight: CGFloat

    @Environment(\.widgetFont) var widgetFont

    var body: some View {
        HStack(spacing: 6) {
            if showCava {
                CavaBarsView(
                    isPlaying: song.state == .playing,
                    barCount: barCount,
                    barWidth: barWidth,
                    barGap: barGap,
                    barHeight: barHeight
                )
            }
            if showTitle, !song.title.isEmpty {
                Text(song.title)
                    .font(widgetFont.toFont())
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Measurable / Visible wrappers

struct MeasurableNowPlayingContent: View {
    let song: NowPlayingSong
    let showCava: Bool
    let showTitle: Bool
    let barCount: Int
    let barWidth: CGFloat
    let barGap: CGFloat
    let barHeight: CGFloat
    let onSizeChange: (CGFloat) -> Void

    var body: some View {
        NowPlayingContent(song: song, showCava: showCava, showTitle: showTitle, barCount: barCount, barWidth: barWidth, barGap: barGap, barHeight: barHeight)
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
    let showCava: Bool
    let showTitle: Bool
    let barCount: Int
    let barWidth: CGFloat
    let barGap: CGFloat
    let barHeight: CGFloat

    var body: some View {
        NowPlayingContent(song: song, showCava: showCava, showTitle: showTitle, barCount: barCount, barWidth: barWidth, barGap: barGap, barHeight: barHeight)
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
