import SwiftUI

struct GlanceActionSettings: View {
    let id: String
    @ObservedObject private var manager = ConfigManager.shared
    private var editor: ModuleSettingsEditor { .init(id: id) }
    var body: some View {
        SettingsSection(title: "Click & scroll actions", subtitle: editor.values["native-source"] != nil ? "Keep the module's normal behavior or choose your own click destination. Playback buttons keep their individual actions." : "Choose an installed app, browser, terminal, folder, or website. Shell commands remain available for custom actions.", area: .behavior, keywords: ["app", "application", "browser", "terminal", "folder", "website", "shortcut", "Click", "Double click", "click-left", "click-middle", "click-right", "double-click-left", "double-click-middle", "double-click-right", "native-click-action", "native-source", "scroll-down", "scroll-up"]) {
            if editor.values["native-source"] != nil {
                GlanceActionControl(id: id, key: "native-click-action", title: "Click", native: true)
            } else {
                ForEach(["click-left", "click-middle", "click-right", "scroll-up", "scroll-down"], id: \.self) { key in
                    GlanceActionControl(id: id, key: key, title: GlanceFormattingCatalog.title(key))
                }
                DisclosureGroup("Double click") {
                    ForEach(["double-click-left", "double-click-middle", "double-click-right"], id: \.self) { key in
                        GlanceActionControl(id: id, key: key, title: GlanceFormattingCatalog.title(key))
                    }
                }
            }
        }
    }
}

struct GlanceActionControl: View {
    let id: String
    let key: String
    let title: String
    var native = false
    @ObservedObject private var manager = ConfigManager.shared
    private var editor: ModuleSettingsEditor { .init(id: id) }
    private var command: String { editor.values[key]?.stringValue ?? (native ? "module" : "") }
    private var mode: String { native ? command : command.isEmpty ? "none" : command.hasPrefix("glance:") ? String(command.dropFirst(7)) : "shell" }
    private var selection: Binding<String> {
        Binding(get: { mode }, set: { choice in
            if choice == "shell" {
                if command.isEmpty || command.hasPrefix("glance:") { editor.string(key).wrappedValue = " " }
            } else { editor.string(key, removeEmpty: true).wrappedValue = native ? choice : choice == "none" ? "" : "glance:" + choice }
        })
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker(title, selection: selection) {
                if native { Text("Module default").tag("module") }
                Text("None").tag("none")
                Text("Open terminal").tag("terminal")
                Text("Open browser / website").tag("browser")
                Text("Open folder").tag("files")
                Text("Open application").tag("open-app")
                Text("Open Glance settings").tag("settings")
                Text("Shuffle widget colors").tag("shuffle-colors")
                Text("Sound settings").tag("sound")
                Text("Network settings").tag("network")
                Text("Bluetooth settings").tag("bluetooth")
                Text("Notification settings").tag("notifications")
                Text("Privacy settings").tag("privacy")
                if native { Text("App launcher").tag("launcher"); Text("Power menu").tag("power") }
                else { Text("Shell command").tag("shell") }
                if native && !["module", "none", "terminal", "browser", "files", "open-app", "settings", "shuffle-colors", "sound", "network", "bluetooth", "notifications", "privacy", "launcher", "power"].contains(mode) { Text(command).tag(command) }
            }
            if native, mode == "module", ["terminal", "browser", "files", "open-app"].contains(editor.values["native-action"]?.stringValue ?? "") {
                GlanceShortcutSettings(id: id)
            }
            if mode == "shell" {
                SettingsTextField(label: "Command", value: editor.string(key, removeEmpty: true), prompt: "Shell command")
            } else if ["terminal", "browser", "files", "open-app"].contains(mode) {
                GlanceShortcutSettings(id: id, actionKey: key, destinationPrefix: key + "-")
            }
        }
    }
}
