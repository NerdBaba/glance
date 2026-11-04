import SwiftUI

final class BarRuntimeActivity: ObservableObject {
    static let shared = BarRuntimeActivity()
    @Published var visible = true
}

private struct BarCollectorsActiveKey: EnvironmentKey { static let defaultValue = true }
extension EnvironmentValues {
    var barCollectorsActive: Bool {
        get { self[BarCollectorsActiveKey.self] }
        set { self[BarCollectorsActiveKey.self] = newValue }
    }
}

/// Demand is computed from displayed modules, never from unused config sections.
struct BarCollectorDemand: Equatable {
    var music = false
    var musicClock = false
    var system = false
    var cores = false

    init(widgets: WidgetsSection?, active: Bool) {
        guard active, let widgets else { return }
        for item in widgets.displayed {
            let values = (widgets.config(for: item.id) ?? [:]).merging(item.inlineParams) { _, inline in inline }
            let source = values["native-source"]?.stringValue ?? ""
            music = music || ["default.nowplaying", "default.mediacontrols"].contains(item.id)
                || (item.id.hasPrefix("script.") && ["music", "music-artwork", "visualizer"].contains(source))
            // State-only controls, artwork and visualizers do not need the
            // one-second elapsed publication. Full formatted songs retain it.
            if item.id == "default.nowplaying" {
                musicClock = musicClock || values["show-position"]?.boolValue == true || values["show-progress"]?.boolValue == true
            } else if item.id.hasPrefix("script."), source == "music" { musicClock = true }
            system = system || item.id == "default.systemmonitor"
                || (item.id.hasPrefix("script.") && ["cpu", "memory"].contains(source))
            if item.id.hasPrefix("script."), ["cpu", "memory"].contains(source) {
                cores = cores || values.values.contains { $0.stringValue?.contains("%percentage-core") == true }
            }
        }
    }
}

struct BarCollectorModifier: ViewModifier {
    let demand: BarCollectorDemand
    @State private var id = UUID()
    func body(content: Content) -> some View {
        content.onAppear { apply(demand) }
            .onChange(of: demand) { _, value in apply(value) }
            .onDisappear {
                NowPlayingManager.shared.setDemand(id, enabled: false)
                SystemMonitorViewModel.shared.setDemand(id, enabled: false)
            }
    }
    private func apply(_ value: BarCollectorDemand) {
        NowPlayingManager.shared.setDemand(id, enabled: value.music, elapsed: value.musicClock)
        SystemMonitorViewModel.shared.setDemand(id, enabled: value.system, cores: value.cores)
    }
}
