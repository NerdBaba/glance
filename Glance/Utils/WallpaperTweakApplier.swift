import Foundation

/// Applies a confirmed `BarTweakPatch` to the live config via
/// `ConfigManager.updateConfigValues`. It writes validated scalar decisions
/// (formation, accent) and composes the widget list from the chosen composition
/// archetype + anchor. Call after the user confirms a preview.
enum WallpaperTweakApplier {

    private static let canonicalIDs: Set<String> = [
        "default.spaces", "default.activeapp", "default.inputlanguage", "default.clipboard",
        "default.weather", "default.nowplaying",
        "default.systemmonitor", "default.disk", "default.network",
        "default.volume", "default.brightness", "default.battery", "default.bluetooth",
        "default.time",
    ]

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

        let composition = patch.composition ?? .classicStatus
        let list = WallpaperComposer.compose(
            composition,
            anchor: patch.feature,
            available: availableWidgetIDs(manager: manager),
            includeSystem: true)
        pairs.append(("widgets.displayed", tomlArray(list)))

        guard !pairs.isEmpty else { return false }
        manager.updateConfigValues(pairs: pairs)
        return true
    }

    private static func availableWidgetIDs(manager: ConfigManager) -> Set<String> {
        var set = canonicalIDs
        if let displayed = manager.config.rootToml.widgets?.displayed {
            for widget in displayed where !["divider", "spacer"].contains(widget.id) {
                set.insert(widget.id)
            }
        }
        return set
    }

    private static func tomlArray(_ ids: [String]) -> String {
        "[" + ids.map { "\"\($0)\"" }.joined(separator: ", ") + "]"
    }
}
