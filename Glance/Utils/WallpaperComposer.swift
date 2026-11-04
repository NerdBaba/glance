import Foundation

/// A bar composition archetype. Generative UI looks "designed" when the layout
/// varies by a recognizable, coherent pattern (not just recolor) — this is the
/// structure axis. Each archetype arranges widgets into role-based clusters with
/// spacers/dividers and a visual anchor.
enum BarComposition: String, CaseIterable {
    case classicStatus    // left status cluster · center anchor · right system tray
    case flanked          // two-side clusters, breathing room in the middle
    case asymmetricDock   // docked left cluster, essentials pinned right
    case layeredPills     // multi-group pills across the width

    var label: String {
        switch self {
        case .classicStatus: return "Classic status"
        case .flanked: return "Flanked"
        case .asymmetricDock: return "Asymmetric dock"
        case .layeredPills: return "Layered pills"
        }
    }
}

/// Semantic role of a widget, used to place it deliberately within an archetype.
enum WidgetRole {
    case status       // spaces, active app, input language, clipboard
    case primary      // weather, now playing (media/anchor candidates)
    case monitor      // system monitor, disk, network
    case system       // volume, brightness, battery, bluetooth
    case clock        // time
    case other
}

/// Composes a concrete `widgets.displayed` list from a composition archetype, an
/// optional anchor widget, the available widget set, and the template's style.
/// Stays within the given tokens — it only orders/selects real widgets.
enum WallpaperComposer {

    static func role(of widget: String) -> WidgetRole {
        switch widget {
        case "default.spaces", "default.activeapp", "default.inputlanguage", "default.clipboard": return .status
        case "default.weather", "default.nowplaying": return .primary
        case "default.systemmonitor", "default.disk", "default.network": return .monitor
        case "default.volume", "default.brightness", "default.battery", "default.bluetooth": return .system
        case "default.time": return .clock
        default: return .other
        }
    }

    /// Prefer `anchor` (if available and role-suitable), else pick the first
    /// available primary widget, else fall back to the clock.
    static func pickAnchor(anchor: String?, available: Set<String>) -> String {
        if let anchor, available.contains(anchor), role(of: anchor) != .other {
            return anchor
        }
        for candidate in ["default.weather", "default.nowplaying", "default.systemmonitor"] {
            if available.contains(candidate) { return candidate }
        }
        return "default.time"
    }

    static func compose(
        _ composition: BarComposition,
        anchor: String?,
        available: Set<String>,
        includeSystem: Bool
    ) -> [String] {
        var out: [String] = []
        func add(_ widget: String) {
            if available.contains(widget) && !out.contains(widget) { out.append(widget) }
        }
        func addRole(_ targetRole: WidgetRole, maxCount: Int = .max) {
            var added = 0
            for id in orderedIDs where Self.role(of: id) == targetRole && added < maxCount {
                guard available.contains(id), !out.contains(id) else { continue }
                out.append(id); added += 1
            }
        }

        let emphasis = pickAnchor(anchor: anchor, available: available)

        switch composition {
        case .classicStatus:
            // left: status · divider · anchor-center · spacer · monitor · spacer · system · divider · time
            addRole(.status, maxCount: 2)
            out.append("divider")
            add(emphasis)
            out.append("spacer")
            addRole(.monitor, maxCount: 2)
            if includeSystem { addRole(.system, maxCount: 2) }
            out.append("divider")
            addRole(.clock, maxCount: 1)

        case .flanked:
            // left cluster (status + primary), right cluster (monitor + system + clock)
            addRole(.status, maxCount: 2)
            addRole(.primary, maxCount: 1)
            out.append("spacer")
            out.append("spacer")
            addRole(.monitor, maxCount: 2)
            if includeSystem { addRole(.system, maxCount: 2) }
            out.append("divider")
            addRole(.clock, maxCount: 1)

        case .asymmetricDock:
            // docked left cluster, essentials right — a compact shelf
            addRole(.primary, maxCount: 1)
            addRole(.status, maxCount: 2)
            out.append("spacer")
            if includeSystem { addRole(.system, maxCount: 3) }
            out.append("divider")
            addRole(.clock, maxCount: 1)

        case .layeredPills:
            // group by role into pill clusters separated by spacers
            addRole(.status, maxCount: 2)
            out.append("spacer")
            addRole(.primary, maxCount: 2)
            out.append("spacer")
            addRole(.monitor, maxCount: 2)
            if includeSystem {
                out.append("spacer")
                addRole(.system, maxCount: 2)
            }
            out.append("spacer")
            addRole(.clock, maxCount: 1)
        }

        // Guarantee a clock is present.
        if !out.contains("default.time") { out.append("default.time") }
        return out
    }

    private static let orderedIDs: [String] = [
        "default.spaces", "default.activeapp", "default.inputlanguage", "default.clipboard",
        "default.weather", "default.nowplaying",
        "default.systemmonitor", "default.disk", "default.network",
        "default.volume", "default.brightness", "default.battery", "default.bluetooth",
        "default.time",
    ]
}
