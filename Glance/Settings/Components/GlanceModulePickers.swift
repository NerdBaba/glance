import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct GlanceComponentIconControl: View {
    let id: String
    let key: String
    let title: String
    @State private var presented = false
    private var editor: ModuleSettingsEditor { .init(id: id) }
    private var symbol: Binding<String> { editor.string("native-symbol-" + key, removeEmpty: true) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                if !symbol.wrappedValue.isEmpty {
                    Image(nsImage: GlanceInlineIcons.image(symbol.wrappedValue, size: 16) ?? NSImage()).frame(width: 24)
                    Button("Restore glyph") { symbol.wrappedValue = "" }
                }
                Button("Choose icon…") { presented = true }
            }
            GlanceFormattedField(id: id, key: key, title: symbol.wrappedValue.isEmpty ? "Glyph / text" : "Original glyph (restored when the icon is removed)")
                .disabled(!symbol.wrappedValue.isEmpty)
        }
        .popover(isPresented: $presented) {
            IconPickerView(selectedIcon: symbol, recentIcons: [], onIconSelected: {
                symbol.wrappedValue = $0
                presented = false
            }, onDismiss: { presented = false })
        }
    }
}

struct GlanceShortcutSettings: View {
    let id: String
    private var editor: ModuleSettingsEditor { .init(id: id) }
    var actionKey = "native-action"
    var destinationPrefix = "action-"
    private var action: String {
        let action = editor.values[actionKey]?.stringValue ?? ""
        return action.hasPrefix("glance:") ? String(action.dropFirst(7)) : action
    }

    @ViewBuilder var body: some View {
        if ["browser", "terminal", "files", "open-app"].contains(action) || action.hasPrefix("https://") {
            GlanceApplicationPicker(selection: editor.string(destinationPrefix + "app", removeEmpty: true), role: action)
            if action == "browser" {
                SettingsTextField(label: "Website", value: editor.string(destinationPrefix + "url", default: "https://www.google.com"))
            }
            if action == "files" {
                HStack {
                    Text("Folder")
                    Spacer()
                    Text(GlanceModuleAction.folder(GlanceModuleAction.destinationConfig(editor.values, prefix: destinationPrefix)).path).lineLimit(1).truncationMode(.middle).foregroundStyle(.secondary)
                    Button("Choose…") {
                        let panel = NSOpenPanel()
                        panel.canChooseDirectories = true
                        panel.canChooseFiles = false
                        panel.allowsMultipleSelection = false
                        if panel.runModal() == .OK, let url = panel.url {
                            editor.string(destinationPrefix + "folder", removeEmpty: true).wrappedValue = url.path
                        }
                    }
                    Button("Home") { editor.string(destinationPrefix + "folder", removeEmpty: true).wrappedValue = "" }
                }
            }
        }
    }
}

struct GlanceApplicationPicker: View {
    @Binding var selection: String
    let role: String
    @State private var presented = false
    @State private var search = ""
    @State private var showAll = false
    @State private var applications: [LaunchableApplication] = []

    private var defaultName: String {
        role == "terminal" ? "Terminal" : role == "files" ? "Finder" : role == "open-app" ? "Choose an application" : "Default browser"
    }
    private var selectedName: String {
        selection.isEmpty ? defaultName : URL(fileURLWithPath: selection).deletingPathExtension().lastPathComponent
    }
    private var matches: [LaunchableApplication] {
        applications.filter { app in
            if !search.isEmpty { return app.name.localizedCaseInsensitiveContains(search) }
            if showAll { return true }
            if role == "terminal" { return ["terminal", "iterm", "kitty", "alacritty", "wezterm", "warp", "ghostty", "rio"].contains { app.name.lowercased().contains($0) } }
            if role == "files" { return ["finder", "forklift", "path finder", "marta", "commander"].contains { app.name.lowercased().contains($0) } }
            if role == "open-app" { return true }
            if let url = URL(string: "https://example.com"), NSWorkspace.shared.urlsForApplications(toOpen: url).contains(app.url) { return true }
            let known = ["safari", "firefox", "chrome", "chromium", "edge", "brave", "vivaldi", "arc", "opera", "orion", "zen", "librewolf", "waterfox", "tor browser", "duckduckgo", "safari technology preview", "firefox developer edition", "firefox nightly", "google chrome beta", "google chrome dev", "google chrome canary", "microsoft edge beta"]
            if known.contains(where: { app.name.lowercased() == $0 || app.name.lowercased().hasSuffix(" " + $0) || app.name.lowercased() == $0 + " browser" }) { return true }
            return false
        }
    }
    var body: some View {
        HStack {
            Text(role == "terminal" ? "Terminal application" : role == "files" ? "File manager" : role == "open-app" ? "Application" : "Browser")
            Spacer()
            Button { search = ""; applications = LaunchableApplication.installed; presented = true } label: {
                HStack {
                    if !selection.isEmpty {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: selection)).resizable().frame(width: 20, height: 20)
                    }
                    Text(selectedName)
                    if !selection.isEmpty && !FileManager.default.fileExists(atPath: selection) { Image(systemName: "exclamationmark.triangle").help("This app is unavailable. Choose an installed application.") }
                    Image(systemName: "chevron.up.chevron.down").font(.caption2)
                }
            }
        }
        .popover(isPresented: $presented) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Choose application").font(.headline)
                TextField("Search installed applications", text: $search)
                if role != "open-app" { Toggle("Show all installed applications", isOn: $showAll) }
                Button(defaultName) { selection = ""; presented = false }
                Divider()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(matches) { app in
                            Button { selection = app.url.path; presented = false } label: {
                                HStack {
                                    Image(nsImage: app.icon).resizable().frame(width: 24, height: 24)
                                    Text(app.name)
                                    Spacer()
                                    if selection == app.url.path { Image(systemName: "checkmark") }
                                }.padding(6).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                        }
                        if matches.isEmpty { Text("Search all apps or choose an app below.").foregroundStyle(.secondary) }
                    }
                }
                Button("Choose another application…") {
                    let panel = NSOpenPanel()
                    panel.allowedContentTypes = [.applicationBundle]
                    panel.allowsMultipleSelection = false
                    panel.directoryURL = URL(fileURLWithPath: "/Applications")
                    if panel.runModal() == .OK, let url = panel.url {
                        selection = url.path
                        presented = false
                    }
                }
            }.padding(16).frame(width: 340, height: 420)
        }
    }
}

struct WeatherModuleSettings: View {
    let id: String
    private var editor: ModuleSettingsEditor { .init(id: id) }
    var body: some View {
        Picker("Weather provider", selection: editor.string("provider", default: "met-no")) {
            Text("MET Norway").tag("met-no")
            Text("Open-Meteo").tag("open-meteo")
        }
        Toggle("Approximate location from IP", isOn: editor.bool("use-ip-fallback", default: true))
        DisclosureGroup("Manual location") {
            SettingsTextField(label: "Latitude", value: coordinate("latitude"))
            SettingsTextField(label: "Longitude", value: coordinate("longitude"))
            SettingsTextField(label: "Location name", value: editor.string("location-name", removeEmpty: true))
            Button("Use automatic location") {
                editor.manager.removeConfigValue(key: "widgets.\(id).latitude")
                editor.manager.removeConfigValue(key: "widgets.\(id).longitude")
            }
        }
    }
    private func coordinate(_ key: String) -> Binding<String> {
        Binding(get: { editor.values[key]?.doubleValue.map { String($0) } ?? "" }, set: { text in
            if text.isEmpty { editor.manager.removeConfigValue(key: "widgets.\(id).\(key)") }
            else if let value = Double(text), value.isFinite,
                    (key == "latitude" ? -90.0...90.0 : -180.0...180.0).contains(value) {
                editor.manager.updateConfigValue(key: "widgets.\(id).\(key)", newValue: String(value))
            }
        })
    }
}

struct GlanceSymbolPickerButton: View {
    @Binding var selection: String
    let title: String
    @State private var presented = false
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            if !selection.isEmpty {
                Image(nsImage: GlanceInlineIcons.image(selection, size: 16) ?? NSImage())
                Button("Use glyph") { selection = "" }
            }
            Button("Choose icon…") { presented = true }
        }
        .popover(isPresented: $presented) {
            IconPickerView(selectedIcon: $selection, recentIcons: [], onIconSelected: {
                selection = $0; presented = false
            }, onDismiss: { presented = false })
        }
    }
}
