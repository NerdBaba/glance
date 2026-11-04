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
///
/// Polish rules derived from OpenAI's generative-UI guidance:
/// - Restraint: a small total budget, not every widget at once.
/// - One focal point: the anchor is always present and prominent.
/// - Quiet supporting clusters (status/monitor/system) are kept small.
/// - Grouping is coherent: dividers separate families, spacers give rhythm.
enum WallpaperComposer {

    // Total visible widget budget (excluding dividers/spacers).
    private static let totalBudget = 6
    // Per-cluster caps keep any one group from dominating.
    private static let statusCap = 2
    private static let monitorCap = 2
    private static let systemCap = 2

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
        var count = 0
        func add(_ widget: String, role: WidgetRole) {
            guard count < totalBudget else { return }
            guard available.contains(widget), !out.contains(widget) else { return }
            // Per-cluster caps.
            switch role {
            case .status where out.filter { Self.role(of: $0) == .status }.count >= statusCap: return
            case .monitor where out.filter { Self.role(of: $0) == .monitor }.count >= monitorCap: return
            case .system where out.filter { Self.role(of: $0) == .system }.count >= systemCap: return
            default: break
            }
            out.append(widget)
            count += 1
        }
        func addRole(_ targetRole: WidgetRole, maxCount: Int = .max) {
            var added = 0
            for id in orderedIDs where Self.role(of: id) == targetRole && added < maxCount {
                guard available.contains(id), !out.contains(id), count < totalBudget else { continue }
                out.append(id)
                count += 1
                added += 1
            }
        }

        let emphasis = pickAnchor(anchor: anchor, available: available)
        // Ensure the anchor is not double-added later.
        add(emphasis, role: role(of: emphasis))

        switch composition {
        case .classicStatus:
            // status · divider · anchor-center · spacer · (monitor/system) · divider · clock
            addRole(.status, maxCount: statusCap)
            if !out.contains(emphasis) { add(emphasis, role: role(of: emphasis)) }
            out.append("divider")
            if !out.contains(emphasis) { out.append(emphasis); count += 1 }
            if count < totalBudget { addRole(.monitor, maxCount: monitorCap) }
            if includeSystem && count < totalBudget { addRole(.system, maxCount: systemCap) }
            out.append("divider")
            addRole(.clock, maxCount: 1)

        case .flanked:
            // left cluster (status + anchor), right cluster (monitor/system + clock), open middle
            addRole(.status, maxCount: statusCap)
            if !out.contains(emphasis) { add(emphasis, role: role(of: emphasis)) }
            out.append("spacer")
            out.append("spacer")
            if count < totalBudget { addRole(.monitor, maxCount: monitorCap) }
            if includeSystem && count < totalBudget { addRole(.system, maxCount: systemCap) }
            out.append("divider")
            addRole(.clock, maxCount: 1)

        case .asymmetricDock:
            // compact shelf: anchor first, then a few system essentials, clock pinned right
            if !out.contains(emphasis) { add(emphasis, role: role(of: emphasis)) }
            addRole(.status, maxCount: 1)
            out.append("spacer")
            if includeSystem && count < totalBudget { addRole(.system, maxCount: systemCap) }
            out.append("divider")
            addRole(.clock, maxCount: 1)

        case .layeredPills:
            // distinct pill groups with literal spacers between
            addRole(.status, maxCount: 1)
            out.append("spacer")
            if !out.contains(emphasis) { add(emphasis, role: role(of: emphasis)) }
            if count < totalBudget { addRole(.monitor, maxCount: 1) }
            out.append("spacer")
            if includeSystem && count < totalBudget { addRole(.system, maxCount: 1) }
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
