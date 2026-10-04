import SwiftUI

struct BarPreviewActiveApp: View {
    @Environment(\.widgetFont) private var widgetFont

    var body: some View {
        Text(ProcessInfo.processInfo.environment["GLANCE_PREVIEW_WINDOW_TITLE"] ?? "me@desktop: ~")
            .font(widgetFont.toFont())
            .lineLimit(1)
            .experimentalConfiguration(horizontalPadding: 10)
            .frame(maxHeight: .infinity)
    }
}

/// Preview-only stable track content lets bar screenshots be compared without
/// starting a player or changing the user's media session.
struct BarPreviewNowPlaying: View {
    let config: ConfigProvider
    @Environment(\.widgetFont) private var widgetFont
    @Environment(\.appearance) private var appearance

    private var previewTitle: String {
        ProcessInfo.processInfo.environment["GLANCE_PREVIEW_TRACK_TITLE"] ?? "Ever Falling"
    }
    private var previewArtist: String {
        ProcessInfo.processInfo.environment["GLANCE_PREVIEW_TRACK_ARTIST"] ?? "Amon Tobin"
    }
    private var showIcon: Bool { config.config["show-icon"]?.boolValue ?? true }
    private var showTitle: Bool { config.config["show-title"]?.boolValue ?? true }
    private var showArtist: Bool { config.config["show-artist"]?.boolValue ?? false }
    private var showAlbum: Bool { config.config["show-album"]?.boolValue ?? false }
    private var showVisualizer: Bool { config.config["show-visualizer"]?.boolValue ?? false }
    private var titleMaxLength: Int { config.config["title-max-length"]?.intValue ?? 30 }
    private var artistMaxLength: Int { config.config["artist-max-length"]?.intValue ?? 20 }
    private var albumMaxLength: Int { config.config["album-max-length"]?.intValue ?? 20 }
    private var separator: String { config.config["separator"]?.stringValue ?? " - " }
    private var showPosition: Bool { config.config["show-position"]?.boolValue ?? false }
    private var showProgress: Bool { config.config["show-progress"]?.boolValue ?? false }
    private var showDuration: Bool { config.config["show-duration"]?.boolValue ?? false }
    private var timeSeparator: String { config.config["time-separator"]?.stringValue ?? " / " }
    private var contentSpacing: CGFloat { config.config["content-spacing"]?.doubleValue ?? 5 }
    private var contentPadding: CGFloat { config.config["content-padding"]?.doubleValue ?? 4 }
    private var timeOpacity: Double { config.config["time-opacity"]?.doubleValue ?? 0.72 }
    private var position: Double {
        ProcessInfo.processInfo.environment["GLANCE_PREVIEW_TRACK_POSITION"].flatMap(Double.init) ?? 15
    }
    private var duration: Double {
        ProcessInfo.processInfo.environment["GLANCE_PREVIEW_TRACK_DURATION"].flatMap(Double.init) ?? 408
    }
    private var visualizerPosition: VisualizerPosition {
        VisualizerPosition(
            rawValue: config.config["visualizer-position"]?.stringValue ?? "right"
        ) ?? .right
    }

    var body: some View {
        HStack(spacing: contentSpacing) {
            if visualizerPosition == .left && showVisualizer { visualizer }
            if showIcon {
                Image(systemName: "music.note")
                    .font(.system(size: 12, weight: .medium))
            }
            if visualizerPosition == .afterIcon && showVisualizer { visualizer }
            if !textParts.isEmpty {
                Text(formatMusicLabel(parts: textParts, separator: separator, maxLength: Int(config.config["label-max-length"]?.doubleValue ?? 0)))
                    .font(widgetFont.toFont())
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            if showPosition && showDuration {
                playbackTimeRange(position: position, duration: duration)
            } else if showPosition {
                playbackTimeLabel(position)
            }
            if showProgress {
                NowPlayingProgressLine(position: position, duration: duration, tint: appearance.accentColor)
            }
            if showDuration && !showPosition {
                playbackTimeLabel(duration)
            }
            if visualizerPosition == .right && showVisualizer { visualizer }
        }
        .padding(.horizontal, contentPadding)
    }

    private var textParts: [String] {
        var parts: [String] = []
        let artistFirst = config.config["artist-first"]?.boolValue ?? false
        if artistFirst, showArtist { parts.append(truncate(previewArtist, to: artistMaxLength)) }
        if showTitle { parts.append(truncate(previewTitle, to: titleMaxLength)) }
        if !artistFirst, showArtist { parts.append(truncate(previewArtist, to: artistMaxLength)) }
        if showAlbum { parts.append(truncate("Foley Room", to: albumMaxLength)) }
        return parts
    }

    @ViewBuilder
    private func playbackTimeLabel(_ seconds: Double) -> some View {
        Text(formatPlaybackTime(seconds))
            .font(widgetFont.toFont())
            .monospacedDigit()
            .opacity(timeOpacity)
    }

    private func playbackTimeRange(position: Double, duration: Double) -> some View {
        Text("\(formatPlaybackTime(position))\(timeSeparator)\(formatPlaybackTime(duration))")
            .font(widgetFont.toFont())
            .monospacedDigit()
            .opacity(timeOpacity)
    }

    private var visualizer: some View {
        HStack(alignment: .center, spacing: 1) {
            ForEach([5.0, 9.0, 12.0, 8.0, 4.0], id: \.self) { height in
                Capsule()
                    .fill(appearance.accentColor)
                    .frame(width: 2, height: height)
            }
        }
    }

    private func truncate(_ text: String, to length: Int) -> String {
        guard text.count > length else { return text }
        return String(text.prefix(max(0, length))) + "..."
    }
}

func formatPlaybackTime(_ seconds: Double) -> String {
    let wholeSeconds = max(0, Int(seconds))
    return "\(wholeSeconds / 60):\(String(format: "%02d", wholeSeconds % 60))"
}

/// The same assembled-label truncation is used for live metadata and exports.
func formatMusicLabel(parts: [String], separator: String, maxLength: Int) -> String {
    let text = parts.joined(separator: separator)
    guard maxLength > 0, text.count > maxLength else { return text }
    let limit = min(maxLength, 500)
    return limit > 3 ? String(text.prefix(limit - 3)) + "..." : String(text.prefix(limit))
}

/// Static media controls keep the image renderer away from button hit targets
/// and MediaRemote actions while preserving the bar's visual rhythm.
struct BarPreviewMediaControls: View {
    let config: ConfigProvider
    @Environment(\.widgetFont) private var widgetFont

    private var showsPrevious: Bool { config.config["show-previous"]?.boolValue ?? true }
    private var showsPlayPause: Bool { config.config["show-play-pause"]?.boolValue ?? true }
    private var showsNext: Bool { config.config["show-next"]?.boolValue ?? true }
    private var spacing: CGFloat { config.config["control-spacing"]?.doubleValue ?? 5 }

    var body: some View {
        HStack(spacing: spacing) {
            if showsPrevious { PolybarIcon(config: config, glyph: config.config["icon-prev"]?.stringValue, systemName: "backward.end.fill") }
            if showsPlayPause {
                let playing = ProcessInfo.processInfo.environment["GLANCE_PREVIEW_PLAYING"] != "false"
                PolybarIcon(config: config, glyph: config.config[playing ? "icon-pause" : "icon-play"]?.stringValue, systemName: playing ? "pause.fill" : "play.fill")
            }
            if showsNext { PolybarIcon(config: config, glyph: config.config["icon-next"]?.stringValue, systemName: "forward.end.fill") }
        }
        .font(widgetFont.toFont())
        .experimentalConfiguration(horizontalPadding: 3)
        .frame(maxHeight: .infinity)
    }
}

/// Previous, play/pause, and next controls for Polybar-style media sections.
/// The MediaRemote commands follow the same local path as Glance's player popup.
struct MediaControlsWidget: View {
    @EnvironmentObject private var config: ConfigProvider
    @Environment(\.widgetFont) private var widgetFont
    @ObservedObject private var player = NowPlayingManager.shared

    private var showsPrevious: Bool { config.config["show-previous"]?.boolValue ?? true }
    private var showsPlayPause: Bool { config.config["show-play-pause"]?.boolValue ?? true }
    private var showsNext: Bool { config.config["show-next"]?.boolValue ?? true }
    private var isPlaying: Bool { player.nowPlaying?.state == .playing }
    private var spacing: CGFloat { config.config["control-spacing"]?.doubleValue ?? 5 }

    var body: some View {
        HStack(spacing: spacing) {
            if showsPrevious {
                commandButton("backward.end.fill", glyphKey: "icon-prev", command: .previousTrack, help: "Previous track")
            }
            if showsPlayPause {
                commandButton(
                    isPlaying ? "pause.fill" : "play.fill",
                    glyphKey: isPlaying ? "icon-pause" : "icon-play",
                    command: .togglePlayPause,
                    help: isPlaying ? "Pause" : "Play"
                )
            }
            if showsNext {
                commandButton("forward.end.fill", glyphKey: "icon-next", command: .nextTrack, help: "Next track")
            }
        }
        .font(widgetFont.toFont())
        .experimentalConfiguration(horizontalPadding: 3)
        .frame(maxHeight: .infinity)
    }

    private func commandButton(_ symbol: String, glyphKey: String, command: MRCommand, help: String) -> some View {
        Button {
            MediaRemoteProvider.shared.sendCommand(command)
        } label: {
            PolybarIcon(config: config, glyph: config.config[glyphKey]?.stringValue, systemName: symbol)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

/// Polybar icon-font glyphs can be used without replacing native widget actions.
struct PolybarIcon: View {
    let config: ConfigProvider
    let glyph: String?
    let systemName: String
    @Environment(\.widgetFont) private var widgetFont

    var body: some View {
        Group {
            if let glyph, !glyph.isEmpty {
                Text(glyph)
                    .font(FontConfig(
                        fontName: config.config["icon-font-name"]?.stringValue ?? widgetFont.fontName,
                        fontSize: config.config["icon-font-size"]?.doubleValue.map { CGFloat($0) } ?? widgetFont.fontSize,
                        weight: .regular
                    ).toFont())
                    .fixedSize(horizontal: true, vertical: false)
            } else {
                Image(systemName: systemName).font(widgetFont.toFont())
            }
        }
        .tracking(0)
        .offset(y: config.config["icon-offset-y"]?.doubleValue ?? 0)
    }
}
