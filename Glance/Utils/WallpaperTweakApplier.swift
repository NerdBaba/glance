import Foundation

/// Applies a confirmed `BarTweakPatch` to the live config via
/// `ConfigManager.updateConfigValues`. Only validated, in-range decisions are
/// written; everything else is ignored. Call after the user confirms a preview.
enum WallpaperTweakApplier {

    @MainActor
    @discardableResult
    static func apply(patch: BarTweakPatch, to manager: ConfigManager) -> Bool {
        var pairs: [(key: String, value: String)] = []

        if let formation = patch.formation,
           ["floating", "full", "islands", "pills"].contains(formation) {
            pairs.append(("experimental.foreground.formation", formation))
        }

        if let accent = patch.accentIndex, (0...15).contains(accent) {
            pairs.append(("widgets.pywal.accent-index", String(accent)))
        }

        let displayed = displayedWidgets(density: patch.density, manager: manager)
        pairs.append(("widgets.displayed", displayed))

        guard !pairs.isEmpty else { return false }
        manager.updateConfigValues(pairs: pairs)
        return true
    }

    /// Build the TOML array value for `widgets.displayed`.
    private static func displayedWidgets(density: String?, manager: ConfigManager) -> String {
        let current = manager.config.rootToml.widgets?.displayed.map(\.id) ?? []
        var base = current

        switch density {
        case "minimal":
            let essential = ["default.spaces", "default.activeapp", "default.nowplaying", "default.time"]
            let intersection = essential.filter { current.contains($0) }
            base = intersection.isEmpty ? essential : intersection
        case "rich":
            let monitor = ["default.systemmonitor", "default.network", "default.volume",
                           "default.brightness", "default.disk"]
            for widget in monitor where !base.contains(widget) {
                // Insert before the trailing time widget if present, else append.
                if let timeIndex = base.lastIndex(of: "default.time") {
                    base.insert(widget, at: timeIndex)
                } else {
                    base.append(widget)
                }
            }
        default:
            break // balanced keeps the template's widget set.
        }

        return "[" + base.map { "\"\($0)\"" }.joined(separator: ", ") + "]"
    }
}
