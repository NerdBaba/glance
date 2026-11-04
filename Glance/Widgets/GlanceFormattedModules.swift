import SwiftUI

struct GlanceFormattedWeather: View {
    let config: ConfigData
    let manager: ConfigManager
    @ObservedObject private var weather = WeatherViewModel.shared
    @State private var presented = false
    @Environment(\.isBarPreviewRendering) private var preview
    var body: some View {
        var values = config
        if values["native-symbol-label-prefix"] == nil {
            values["native-symbol-label-prefix"] = .string(preview ? "cloud.sun.fill" : weather.currentCondition.symbolName)
        }
        return PolybarFormattedContent(config: values, manager: manager, tokens: [
            "temperature": preview ? "24" : weather.temperature.map { String(format: "%.0f", $0) } ?? "—",
            "feels-like": preview ? "22" : weather.apparentTemperature.map { String(format: "%.0f", $0) } ?? "—",
            "condition": preview ? "clear sky" : weather.currentCondition.description
        ], action: { _ in if !preview { presented.toggle() } })
        .popover(isPresented: $presented, arrowEdge: .top) { WeatherPopup(viewModel: weather) }
        .onAppear { if !preview { weather.configure(from: config) } }
        .onReceive(manager.$config) { _ in if !preview { weather.configure(from: config) } }
    }
}

/// A configurable playback animation, matching Glance's existing music visualizer.
/// It follows play/pause state; it does not pretend to measure audio frequencies.
struct GlanceBarVisualizer: View {
    let config: ConfigData
    let manager: ConfigManager
    @ObservedObject private var player = NowPlayingManager.shared
    @Environment(\.isBarPreviewRendering) private var preview
    @Environment(\.appearance) private var appearance
    // Controlled animation workload for the isolated profiler; no playback or
    // persisted settings are changed, and normal launches cannot enable it.
    @Environment(\.barCollectorsActive) private var collectorsActive
    private static let benchmarkPlayback = CommandLine.arguments.contains("--benchmark-panel")
        && CommandLine.arguments.contains("--benchmark-animate")
    private var playing: Bool { collectorsActive && (preview || Self.benchmarkPlayback || player.nowPlaying?.state == .playing) }
    var body: some View {
        let count = min(max(config["visualizer-count"]?.intValue ?? 40, 3), 100)
        let width = min(max(config["visualizer-width"]?.doubleValue ?? 200, 30), 600)
        let height = min(max(config["visualizer-height"]?.doubleValue ?? 18, 4), 80)
        let palette = manager.config.pywalColors?.colors ?? []
        let first = PolybarModuleStyle.color(config["visualizer-color"]?.stringValue, palette: palette) ?? appearance.accentColor
        let last = PolybarModuleStyle.color(config["visualizer-color-2"]?.stringValue, palette: palette) ?? appearance.foregroundColor
        let gradient = Gradient(colors: [first, last])
        let centered = config["visualizer-baseline"]?.stringValue == "center"
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: !playing || preview)) { timeline in
            Canvas { context, size in
                let time = preview ? 1.2 : timeline.date.timeIntervalSinceReferenceDate
                let step = size.width / Double(count)
                let barWidth = min(max(config["visualizer-bar-width"]?.doubleValue ?? step - 1, 1), step)
                for index in 0..<count {
                    let phase = Double(index) * 0.7
                    let level = playing ? max(0.12, min(1, 0.45 + sin(time * 2.3 + phase) * 0.3 + sin(time * 3.7 + phase * 1.3) * 0.2)) : 0.12
                    let h = size.height * level
                    let rect = CGRect(x: Double(index) * step, y: centered ? (size.height - h) / 2 : size.height - h, width: barWidth, height: h)
                    context.fill(Path(rect), with: .linearGradient(gradient, startPoint: CGPoint(x: 0, y: size.height), endPoint: .zero))
                }
            }.frame(width: width, height: height)
        }
    }
}
