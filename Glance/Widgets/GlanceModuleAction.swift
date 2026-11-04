import AppKit

/// Native shortcuts use workspace APIs and never interpolate a shell command.
enum GlanceModuleAction {
    static func destinationConfig(_ config: ConfigData, prefix: String) -> ConfigData {
        var result = config
        for key in ["app", "url", "folder"] { result["action-" + key] = config[prefix + key] }
        return result
    }

    /// Returns true for native actions even if the destination is unavailable,
    /// so a reserved action can never fall through to shell execution.
    @MainActor static func perform(_ command: String, config: ConfigData) -> Bool {
        switch command {
        case "none", "": return true
        case "terminal", "open-app": openApplication(config: config, fallback: command == "terminal" ? "/System/Applications/Utilities/Terminal.app" : nil)
        case "files": openResource(folder(config), config: config)
        case "browser":
            let raw = config["action-url"]?.stringValue ?? "https://www.google.com"
            if let url = URL(string: raw), ["http", "https"].contains(url.scheme?.lowercased() ?? "") { openResource(url, config: config) }
        case "settings", "style": SettingsWindowController.shared.showSettings()
        case "shuffle-colors": ConfigManager.shared.shuffleWidgetPalette()
        case "sound", "network", "bluetooth", "notifications", "privacy", "updates":
            let panes = ["sound": "com.apple.Sound-Settings.extension", "network": "com.apple.Network-Settings.extension", "bluetooth": "com.apple.Bluetooth-Settings.extension", "notifications": "com.apple.Notifications-Settings.extension", "privacy": "com.apple.settings.PrivacySecurity.extension", "updates": "com.apple.Software-Update-Settings.extension"]
            if let pane = panes[command], let url = URL(string: "x-apple.systempreferences:" + pane) { NSWorkspace.shared.open(url) }
        default:
            if command.hasPrefix("https://"), let url = URL(string: command) { openResource(url, config: config) }
            else { return false }
        }
        return true
    }
    static func folder(_ config: ConfigData) -> URL {
        guard let path = config["action-folder"]?.stringValue, !path.isEmpty else {
            return FileManager.default.homeDirectoryForCurrentUser
        }
        return URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)
    }
    static func application(_ config: ConfigData) -> URL? {
        guard let path = config["action-app"]?.stringValue, !path.isEmpty else { return nil }
        let url = URL(fileURLWithPath: path)
        guard url.pathExtension.lowercased() == "app", FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }
    static func openApplication(config: ConfigData, fallback: String?) {
        guard let url = application(config) ?? fallback.map({ URL(fileURLWithPath: $0) }) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: .init()) { _, error in
            if let error { AppLogger.shared.error("Unable to open module application: \(error.localizedDescription)", category: .app) }
        }
    }
    static func openResource(_ url: URL, config: ConfigData) {
        if let app = application(config) {
            NSWorkspace.shared.open([url], withApplicationAt: app, configuration: .init()) { _, error in
                if let error { AppLogger.shared.error("Unable to open module destination: \(error.localizedDescription)", category: .app) }
            }
        } else { NSWorkspace.shared.open(url) }
    }
}
