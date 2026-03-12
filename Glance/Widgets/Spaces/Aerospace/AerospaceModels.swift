import AppKit

struct AeroWindow: WindowModel {
    let id: Int
    let title: String
    let appName: String?
    var isFocused: Bool = false
    var appIcon: NSImage?
    let workspace: String?

    enum CodingKeys: String, CodingKey {
        case id = "window-id"
        case title = "window-title"
        case appName = "app-name"
        case workspace
    }

    private static func resolvedTitle(from rawTitle: String) -> String {
        let trimmed = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled" : trimmed
    }

    private static func icon(for appName: String?) -> NSImage? {
        guard let appName else { return nil }
        return IconCache.shared.icon(for: appName)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = Self.resolvedTitle(from: try container.decode(String.self, forKey: .title))
        appName = try container.decodeIfPresent(String.self, forKey: .appName)
        workspace = try container.decodeIfPresent(String.self, forKey: .workspace)
        isFocused = false
        appIcon = Self.icon(for: appName)
    }
}

struct AeroSpace: SpaceModel {
    typealias WindowType = AeroWindow
    let workspace: String
    var id: String { workspace }
    var isFocused: Bool = false
    var windows: [AeroWindow] = []

    enum CodingKeys: String, CodingKey {
        case workspace
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        workspace = try container.decode(String.self, forKey: .workspace)
    }

    init(
        workspace: String,
        isFocused: Bool = false,
        windows: [AeroWindow] = []
    ) {
        self.workspace = workspace
        self.isFocused = isFocused
        self.windows = windows
    }
}
