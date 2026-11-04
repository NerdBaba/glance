import AppKit
import SwiftUI

/// Uses the bar's formatter with sample data, without starting providers,
/// running commands, or attaching working click actions.
struct GlanceModulePreview: View {
    let values: ConfigData
    var field: String? = nil
    var draft: String? = nil
    var sampleValue: Double = 55
    var output: String = "Example output"
    @ObservedObject private var manager = ConfigManager.shared

    private var previewValues: ConfigData {
        var result = values["native-source"]?.stringValue == "music" ? GlanceMusicFormatting.applying(to: values) : values
        result.removeValue(forKey: "native-click-action")
            if result["native-source"]?.stringValue == "music" {
                result["label-toggle"] = result["icon-pause"] ?? .string("Ⅱ")
                result["native-symbol-label-toggle"] = result["native-symbol-icon-pause"]
                for field in ["foreground", "background", "font", "padding"] { result["label-toggle-" + field] = result["icon-pause-" + field] }
                for key in ["prev", "next", "play", "pause", "stop"] {
                    result["label-" + key] = result["icon-" + key]
                    result["native-symbol-label-" + key] = result["native-symbol-icon-" + key]
                    for field in ["foreground", "background", "font", "padding"] { result["label-" + key + "-" + field] = result["icon-" + key + "-" + field] }
                }
            }
        if let field, let draft { result[field] = .string(draft) }
        if let field {
            if field == "format" || field.hasPrefix("format-") && !field.hasSuffix("prefix") && !field.hasSuffix("suffix") {
                result["format"] = result[field]
                if field != "format" {
                    for (key, value) in values where key.hasPrefix(field + "-") {
                        result[key.replacingOccurrences(of: field, with: "format")] = value
                    }
                }
            } else if field.hasPrefix("label") || field.hasPrefix("icon-") {
                if field.hasPrefix("icon-") {
                    result["label-preview"] = result[field]
                    for suffix in ["foreground", "background", "font", "padding"] { result["label-preview-" + suffix] = result[field + "-" + suffix] }
                    result["native-symbol-label-preview"] = result["native-symbol-" + field]
                    result["format"] = .string("<label-preview>")
                } else { result["format"] = .string("<" + field + ">") }
                result.removeValue(forKey: "format-prefix")
                result.removeValue(forKey: "format-suffix")
            } else if GlanceFormattingCatalog.isIcon(field) {
                result["label-preview"] = result[field]
                let base = (field.hasPrefix("ramp-") || field.hasPrefix("animation-")) ? field.split(separator: "-").dropLast().joined(separator: "-") : field.hasPrefix("bar-") ? field.split(separator: "-").dropLast().joined(separator: "-") : "format"
                for suffix in ["foreground", "background", "font", "padding"] { result["label-preview-" + suffix] = result[field + "-" + suffix] ?? result[base + "-" + suffix] }
                result["native-symbol-label-preview"] = result["native-symbol-" + field]
                result["format"] = .string("<label-preview>")
                result.removeValue(forKey: "format-prefix"); result.removeValue(forKey: "format-suffix")
            } else {
                result["format"] = .string(draft ?? "")
                result.removeValue(forKey: "format-prefix")
                result.removeValue(forKey: "format-suffix")
                if let symbol = result["native-symbol-" + field] {
                    result["native-symbol-format"] = symbol
                }
            }
        } else {
            let state = ["music": "online", "volume": "volume", "network": "connected", "disk": "mounted"][result["native-source"]?.stringValue ?? ""]
            if let state, result["format-" + state] != nil {
                for (key, value) in Array(result) where key == "format-" + state || key.hasPrefix("format-" + state + "-") {
                    result[key.replacingOccurrences(of: "format-" + state, with: "format")] = value
                }
            }
            if result["format"] == nil { result["format"] = .string("<label>") }

        }
        if let field, field != "format", !field.hasPrefix("format-") || GlanceFormattingCatalog.isIcon(field) {
            result.removeValue(forKey: "native-symbol-format-prefix")
            result.removeValue(forKey: "native-symbol-format-suffix")
        }
        // An individual field preview must retain the source glyph when its
        // symbol override is cleared, and must not inherit an unrelated icon.
        return result
    }

    private var previewTokens: [String: String] {
        var tokens = GlanceFormattingCatalog.tokens(source: values["native-source"]?.stringValue, output: output)
        if values["native-source"]?.stringValue == "music" {
            tokens["song-details"] = GlanceMusicFormatting.details(title: tokens["title"] ?? "", artist: tokens["artist"] ?? "", album: tokens["album"] ?? "", config: values)
        }
        if values["native-source"]?.stringValue == "date" {
            let formatter = DateFormatter()
            formatter.timeZone = values["time-zone"]?.stringValue.flatMap(TimeZone.init(identifier:)) ?? .current
            let date = Date()
            formatter.dateFormat = values["date-pattern"]?.stringValue ?? "EEE MMM d"
            tokens["date"] = formatter.string(from: date)
            formatter.dateFormat = values["time-pattern"]?.stringValue ?? "HH:mm"
            tokens["time"] = formatter.string(from: date)
        }
        return tokens
    }

    var body: some View {
        let appearance = manager.config.appearance
        let font = appearance.useSingleFont ? appearance.barFont : appearance.widgetFont
        let palette = manager.config.pywalColors?.colors ?? []
        let resolved = previewValues
        let style = PolybarModuleStyle.resolve(values: resolved, id: "script.preview", appearance: appearance, palette: palette)
        let capsule = PolybarModuleStyle.color(values["capsule-background"]?.stringValue, palette: palette)
        ScrollView(.horizontal) {
            Group {
            if GlanceTransitionWidget.isDecoration(values),
               let shape = values["native-transition-shape"]?.stringValue, shape != "original" {
                GlanceTransitionWidget(config: values, manager: manager)
            } else if values["native-source"]?.stringValue == "user" {
                Image(systemName: values["native-symbol-label-prefix"]?.stringValue ?? "person.crop.circle.fill")
                    .resizable().scaledToFit().frame(width: values["user-avatar-size"]?.doubleValue ?? 24, height: values["user-avatar-size"]?.doubleValue ?? 24)
                    .foregroundStyle(appearance.foregroundColor).padding(4)
            } else if values["native-source"]?.stringValue == "visualizer" {
                GlanceVisualizerSettingsPreview(values: values, palette: palette, fallback: appearance.accentColor)
            } else {
            PolybarFormattedContent(config: resolved, manager: manager, value: sampleValue,
                tokens: previewTokens, action: { _ in })
                .environment(\.widgetFont, style.font ?? font)
                .environment(\.glanceCapsuleBackground, capsule)
                .environment(\.appearance, appearance)
                .allowsHitTesting(false)
                .frame(height: min(max(values["format-height"]?.doubleValue ?? 32, 20), 80))
                .fixedSize(horizontal: true, vertical: false)
                .tracking(values["format-tracking"]?.doubleValue ?? 0)
                .polybarModuleStyle(style)
                .background(capsule ?? .clear, in: RoundedRectangle(cornerRadius: values["capsule-radius"]?.doubleValue ?? 0))
            }
            }.environment(\.isEnabled, true).allowsHitTesting(false).padding(10)
        }
        .background(appearance.widgetBackgroundColor, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityLabel("Formatted preview with sample data")
    }
}

struct GlanceFormattedField: View {
    let id: String
    let key: String
    let title: String
    var fallback = ""
    @ObservedObject private var manager = ConfigManager.shared
    @State private var draft = ""
    @State private var iconPresented = false
    @FocusState private var focused: Bool
    private var editor: ModuleSettingsEditor { .init(id: id) }
    private var value: String { PolybarScriptOptions(values: editor.values).string(key) ?? fallback }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.callout)
                Spacer()
                if let symbol = editor.values["native-symbol-" + key]?.stringValue, !symbol.isEmpty {
                    Image(systemName: symbol)
                    Button("Restore glyph") { manager.removeConfigValue(key: "widgets.\(id).native-symbol-" + key) }
                }
                Menu("Insert…") {
                    Section("Live values") {
                        ForEach(GlanceFormattingCatalog.tokenNames(source: editor.values["native-source"]?.stringValue), id: \.self) { name in
                            Button(GlanceFormattingCatalog.tokenTitle(name)) { insert("%" + name + "%") }
                        }
                    }
                    Section("Components") {
                        ForEach(GlanceFormattingCatalog.components(editor.values), id: \.self) { component in
                            Button(GlanceFormattingCatalog.title(component)) { insert("<" + component + ">") }
                        }
                    }
                    Section("Icons & glyphs") {
                        Button("Choose system icon…") { iconPresented = true }
                        ForEach(["●", "○", "◉", "♥", "★", "▶", "Ⅱ", "◀", "━", "─", "▁", "▂", "▄", "▆", "█"], id: \.self) { glyph in
                            Button(glyph) { insert(glyph) }
                        }
                    }
                    Section("Spacing & style") {
                        Button("Space") { insert(" ") }
                        Button("6 point gap") { insert("%{O6px}") }
                        Button("New line") { insert("\n") }
                        Button("Reset text color") { insert("%{F-}") }
                        Button("Reset background") { insert("%{B-}") }
                    }
                }.menuStyle(.borderlessButton).fixedSize()
            }
            TextField("Text, live values, or components", text: $draft, axis: .vertical)
                .lineLimit(1...4).textFieldStyle(.roundedBorder)
                .font(.system(size: 14, design: .monospaced)).focused($focused)
                .onSubmit { commit() }
                .onChange(of: focused) { _, focus in if !focus { commit() } }
            GlanceModulePreview(values: editor.values, field: key, draft: draft)
            Text("Sample preview updates as you type. Return or leaving the field applies your edit.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .popover(isPresented: $iconPresented) {
            IconPickerView(selectedIcon: .constant(""), recentIcons: [], onIconSelected: {
                insert("{{glance-icon:" + $0 + "}}"); iconPresented = false
            }, onDismiss: { iconPresented = false })
        }
        .onAppear { draft = value }
        .onChange(of: value) { _, new in if !focused || editor.values[key] == nil { draft = new } }
        
    }
    private func insert(_ text: String) {
        draft += text
        if !focused { commit() }
    }
    private func commit() {
        guard draft != value else { return }
        editor.scalarString(key).wrappedValue = draft
    }
}

struct GlanceModulePreviewSettings: View {
    let id: String
    @ObservedObject private var manager = ConfigManager.shared
    @State private var sampleValue = 55.0
    @State private var sampleOutput = "Example output"
    @State private var sampleState = "current"
    private var editor: ModuleSettingsEditor { .init(id: id) }
    var body: some View {
        SettingsSection(title: "Preview", subtitle: "Sample data shows how your module will look.", area: .advanced, keywords: ["%.0f%%", "Current layout", "Preview state", "Sample command output", "Sample data", "Sample percentage", "current", "format-connected", "format-disconnected", "format-fail", "format-muted", "format-offline", "format-online", "format-volume", "native-source", "user", "visualizer"]) {
            GlanceModulePreview(values: editor.values, field: sampleState == "current" ? nil : sampleState, sampleValue: sampleValue, output: sampleOutput)
            DisclosureGroup("Sample data") {
                Picker("Preview state", selection: $sampleState) {
                    Text("Current layout").tag("current")
                    ForEach(editor.values.keys.filter { ["format-fail", "format-muted", "format-offline", "format-online", "format-volume", "format-connected", "format-disconnected"].contains($0) }.sorted(), id: \.self) { state in
                        Text(GlanceSimpleLabelEditor.title(state)).tag(state)
                    }
                }
                if !["visualizer", "user"].contains(editor.values["native-source"]?.stringValue ?? "") {
                    ModuleSlider(label: "Sample percentage", value: $sampleValue, range: 0...100, format: "%.0f%%")
                }
                if editor.values["native-source"] == nil { TextField("Sample command output", text: $sampleOutput).textFieldStyle(.roundedBorder) }
            }
        }
    }
}

struct GlanceFormattingSettings: View {
    let id: String
    @ObservedObject private var manager = ConfigManager.shared
    @State private var optionSearch = ""
    @Environment(\.settingsSearchQuery) private var settingsSearch
    @State private var adding = false
    private var editor: ModuleSettingsEditor { .init(id: id) }
    private var keys: [String] { editor.values.keys.filter(GlanceFormattingCatalog.isFormatting).sorted() }

    var body: some View {
        SettingsSection(title: "Advanced formatting", subtitle: "Optional raw formats, component fonts, ramps, and custom options.", area: .advanced, keywords: ["%output%", "<label>", "Add component or option…", "Customize…", "Filter component options", "Layout", "Leading icon", "Raw text & component options", "Remove override", "Text", "alignment", "background", "ellipsis", "font", "foreground", "format", "format-prefix", "label", "margin", "maxlen", "minlen", "overline", "padding", "plus.circle", "underline"]) {
          VStack(alignment: .leading, spacing: 14) {
            GlanceFormattedField(id: id, key: "format", title: "Layout", fallback: "<label>")
            if !keys.contains("label") {
                GlanceFormattedField(id: id, key: "label", title: "Text", fallback: "%output%")
            }
            TextField("Filter component options", text: $optionSearch).textFieldStyle(.roundedBorder)
            ForEach(keys.filter { $0 != "format" && (matchesOption($0)) }, id: \.self) { key in
                DisclosureGroup(GlanceFormattingCatalog.title(key)) {
                    GlanceModuleOptionControl(id: id, key: key).padding(.top, 8)
                    HStack {
                        Text(key).font(.caption.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
                        Spacer()
                        if key.hasPrefix("label"), !key.contains("foreground"), GlanceFormattingCatalog.components(editor.values).contains(key) {
                            Menu("Customize…") {
                                ForEach(["foreground", "background", "font", "padding", "margin", "maxlen", "minlen", "ellipsis", "alignment", "underline", "overline"], id: \.self) { suffix in
                                    Button(GlanceFormattingCatalog.title(suffix)) { addComponentOption(key, suffix: suffix) }
                                        .disabled(editor.values[key + "-" + suffix] != nil)
                                }
                            }.fixedSize()
                        }
                        Button("Remove override", role: .destructive) { manager.removeConfigValue(key: "widgets.\(id).\(key)") }
                    }
                }
            }
            HStack {
                GlanceComponentIconControl(id: id, key: "format-prefix", title: "Leading icon")
            }
            Button("Add component or option…", systemImage: "plus.circle") { adding = true }
          }
        }
        SettingsSection(title: "Icon ramps & progress bars", area: .advanced) { GlanceRampProgressSettings(id: id) }
        SettingsSection(title: "Other module options", subtitle: "Edit additional configured values here, including environment variables and custom tokens. New options must be supported by the module.", area: .advanced, keywords: ["Add option…", "Advanced options", "native-symbol-"]) {
            DisclosureGroup("Advanced options") {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(editor.values.keys.filter { !GlanceFormattingCatalog.isFormatting($0) && !$0.hasPrefix("native-symbol-") && matchesOption($0) }.sorted(), id: \.self) { key in
                        GlanceModuleOptionControl(id: id, key: key)
                    }
                    Button("Add option…") { adding = true }
                }.padding(.top, 12)
            }
        }
        .sheet(isPresented: $adding) { GlanceAddModuleOption(id: id) }
    }
    private func matchesOption(_ key: String) -> Bool {
        let query = optionSearch.isEmpty ? settingsSearch : optionSearch
        return query.isEmpty || key.localizedCaseInsensitiveContains(query) || GlanceFormattingCatalog.title(key).localizedCaseInsensitiveContains(query)
    }
    private func addComponentOption(_ component: String, suffix: String) {
        let value: String
        switch suffix {
        case "foreground", "underline", "overline": value = ModuleSettingsEditor.quoted("pywal:7")
        case "background": value = ModuleSettingsEditor.quoted("pywal:0")
        case "ellipsis": value = "true"
        case "alignment": value = ModuleSettingsEditor.quoted("left")
        case "font", "padding": value = "1"
        case "maxlen": value = "30"
        default: value = "0"
        }
        manager.updateConfigValue(key: "widgets.\(id)." + component + "-" + suffix, newValue: value)
    }
}

struct GlanceModuleOptionControl: View {
    let id: String
    let key: String
    private var editor: ModuleSettingsEditor { .init(id: id) }
    @ViewBuilder var body: some View {
        let title = GlanceFormattingCatalog.title(key)
        if key.hasPrefix("ws-icon-"), key != "ws-icon-default" {
            GlanceWorkspaceIconControl(id: id, key: key)
        } else if key.hasSuffix("-font"), key != "icon-font", key != "icon-font-name" {
            Picker(title, selection: Binding(get: { PolybarScriptOptions(values: editor.values).integer(key) ?? 1 }, set: { editor.integer(key, default: 1).wrappedValue = $0 })) {
                Text("Default font").tag(0)
                ForEach(editor.values.keys.filter { $0.hasPrefix("font-") && Int($0.dropFirst(5)) != nil }.sorted(), id: \.self) { fontKey in
                    if let index = Int(fontKey.dropFirst(5)) {
                        Text("Font \(index + 1) · " + (editor.values[fontKey]?.stringValue ?? "")).tag(index + 1)
                    }
                }
                if !editor.values.keys.contains(where: { $0.hasPrefix("font-") }) { Text("Module font").tag(1) }
            }
        } else if GlanceFormattingCatalog.isColor(key) {
            ModuleColorControl(label: title, value: editor.string(key, removeEmpty: true))
        } else if key.hasPrefix("font-"), Int(key.dropFirst(5)) != nil {
            GlanceComponentFontControl(id: id, key: key)
        } else if GlanceFormattingCatalog.isIcon(key) {
            GlanceComponentIconControl(id: id, key: key, title: title)
        } else if editor.values[key]?.boolValue != nil {
            Toggle(title, isOn: editor.bool(key))
        } else if key.hasSuffix("-alignment") {
            Picker(title, selection: editor.string(key, default: "left")) {
                Text("Left").tag("left"); Text("Center").tag("center"); Text("Right").tag("right")
            }
        } else if editor.values[key]?.intValue != nil || editor.values[key]?.doubleValue != nil {
            GlanceNumberField(id: id, key: key, title: title)
        } else if GlanceFormattingCatalog.isFormatting(key), key.hasPrefix("label") || key.hasPrefix("format") || key.hasPrefix("icon-") {
            GlanceFormattedField(id: id, key: key, title: title)
        } else if editor.values[key]?.stringValue != nil {
            SettingsTextField(label: title, value: editor.scalarString(key))
        } else {
            GlanceStructuredOptionField(id: id, key: key)
        }
    }
}

struct GlanceComponentFontControl: View {
    let id: String
    let key: String
    private var editor: ModuleSettingsEditor { .init(id: id) }
    private var minimumSize: Double { min(max(editor.values["font-min-size"]?.doubleValue ?? 14, 6), 14) }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(GlanceFormattingCatalog.title(key))
                Spacer()
                Button("Choose font…") {
                    let spec = editor.values[key]?.stringValue ?? ""
                    let name = spec.split(separator: ":").first.map(String.init)
                    FontManager.shared.openFontPanel(initialFontName: name, initialSize: 14, parentWindow: NSApp.keyWindow) { name, size, _ in
                        editor.string(key).wrappedValue = name + ":size=" + String(Double(max(CGFloat(minimumSize), size)))
                    }
                }
            }
            SettingsTextField(label: "Font specification", value: editor.string(key), prompt: "Font name:size=14")
            let spec = editor.values[key]?.stringValue ?? ""
            let size = spec.range(of: "size=").flatMap { Double(spec[$0.upperBound...].split(separator: ":").first ?? "14") } ?? 14
            Text("Aa Bb 0123 · Preview").font(.custom(spec.split(separator: ":").first.map(String.init) ?? "", size: min(max(size, minimumSize), 72)))
        }
    }
}

struct GlanceAddModuleOption: View {
    let id: String
    @Environment(\.dismiss) private var dismiss
    @State private var component = "label"
    @State private var name = "custom"
    @State private var key = ""
    @State private var value = ""
    @State private var kind = "text"
    @State private var error = ""
    private var editor: ModuleSettingsEditor { .init(id: id) }
    private var validKey: Bool { !key.isEmpty && key.unicodeScalars.allSatisfy { CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_").contains($0) } }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add component or option").font(.title2)
            Text("Create a reusable label, icon ramp, or progress bar; then insert it into Layout. Existing options are preserved.").foregroundStyle(.secondary)
            Picker("Component", selection: $component) {
                Text("Text label").tag("label"); Text("Icon ramp").tag("ramp"); Text("Progress bar").tag("bar")
            }
            TextField("Component name", text: $name).textFieldStyle(.roundedBorder)
            Button("Create component") { createComponent() }.disabled(name.isEmpty || !name.unicodeScalars.allSatisfy { CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_").contains($0) })
            Divider()
            Menu("Choose a supported option…") {
                ForEach(GlanceFormattingCatalog.suggestions, id: \.0) { item in
                    Button(item.0) { key = item.0; value = item.1; kind = item.2 }
                }
            }
            TextField("Option key", text: $key).textFieldStyle(.roundedBorder)
            Picker("Value type", selection: $kind) { Text("Text").tag("text"); Text("Number").tag("number"); Text("Boolean").tag("bool"); Text("Array / table (TOML)").tag("toml") }
            if kind == "bool" {
                Picker("Value", selection: $value) { Text("True").tag("true"); Text("False").tag("false") }
            } else { TextField("Value", text: $value).textFieldStyle(.roundedBorder) }
            if editor.values[key] != nil { Text("This option already exists. Edit it in its section.").foregroundStyle(.secondary) }
            if !error.isEmpty { Text(error).foregroundStyle(.red) }
            HStack { Button("Cancel") { dismiss() }; Spacer(); Button("Add option") { addOption() }.disabled(!validKey || editor.values[key] != nil) }
        }.padding(24).frame(width: 540)
    }
    private func createComponent() {
        let prefix = component + "-" + name
        var pairs: [(key: String, value: String)]
        switch component {
        case "ramp": pairs = [(prefix + "-0", "▁"), (prefix + "-1", "▄"), (prefix + "-2", "█")].map { ($0.0, ModuleSettingsEditor.quoted($0.1)) }
        case "bar": pairs = [(prefix + "-width", "10"), (prefix + "-fill", ModuleSettingsEditor.quoted("━")), (prefix + "-empty", ModuleSettingsEditor.quoted("─")), (prefix + "-indicator", ModuleSettingsEditor.quoted("●"))]
        default: pairs = [(prefix, ModuleSettingsEditor.quoted("%percentage%"))]
        }
        guard !pairs.contains(where: { editor.values[$0.key] != nil }) else { error = "A component with this name already exists."; return }
        editor.manager.updateConfigValues(pairs: pairs.map { ("widgets.\(id)." + $0.key, $0.value) })
        dismiss()
    }
    private func addOption() {
        let serialized: String
        switch kind {
        case "number": guard let number = Double(value), number.isFinite else { error = "Enter a valid finite number."; return }; serialized = value
        case "bool": guard ["true", "false"].contains(value) else { error = "Choose True or False."; return }; serialized = value
        case "toml":
            do { serialized = try GlanceOptionValue.validated(value) }
            catch { self.error = "Enter a valid TOML array or table."; return }
        default: serialized = ModuleSettingsEditor.quoted(value)
        }
        editor.manager.updateConfigValue(key: "widgets.\(id).\(key)", newValue: serialized)
        dismiss()
    }
}

struct GlanceDatePatternField: View {
    let id: String
    let key: String
    let title: String
    let fallback: String
    @State private var draft = ""
    @FocusState private var focused: Bool
    private var editor: ModuleSettingsEditor { .init(id: id) }
    private var value: String { editor.values[key]?.stringValue ?? fallback }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
            TextField("Date format", text: $draft).textFieldStyle(.roundedBorder).focused($focused)
                .onSubmit { commit() }.onChange(of: focused) { _, focus in if !focus { commit() } }
            let formatter = DateFormatter()
            let _ = { formatter.dateFormat = draft; formatter.timeZone = editor.values["time-zone"]?.stringValue.flatMap(TimeZone.init(identifier:)) ?? .current }()
            Text(formatter.string(from: .now)).font(.system(size: 14, design: .monospaced))
            Text("Example: EEE MMM d · HH:mm · h:mm a · HH:mm:ss").font(.caption).foregroundStyle(.secondary)
        }.onAppear { draft = value }.onChange(of: value) { _, new in if !focused || editor.values[key] == nil { draft = new } }
    }
    private func commit() { if draft != value { editor.string(key).wrappedValue = draft } }
}

struct GlanceNumberField: View {
    let id: String
    let key: String
    let title: String
    @State private var draft = ""
    @State private var error = false
    @FocusState private var focused: Bool
    private var editor: ModuleSettingsEditor { .init(id: id) }
    private var value: String { PolybarScriptOptions(values: editor.values).string(key) ?? "0" }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title); Spacer()
                TextField("Number", text: $draft).frame(width: 100).textFieldStyle(.roundedBorder).focused($focused)
                    .onSubmit { commit() }.onChange(of: focused) { _, focus in if !focus { commit() } }
                Stepper("Adjust value", onIncrement: { adjust(1) }, onDecrement: { adjust(-1) }).labelsHidden()
            }
            if error { Text("Enter a valid finite number. The previous value is still applied.").font(.caption).foregroundStyle(.red) }
        }.onAppear { draft = value }.onChange(of: value) { _, new in if !focused || editor.values[key] == nil { draft = new } }
    }
    private func adjust(_ delta: Double) {
        guard let value = Double(draft), value.isFinite else { error = true; return }
        let next = value + delta
        draft = next.rounded() == next ? String(format: "%.0f", next) : String(next)
        commit()
    }
    private func commit() {
        guard draft != value else { error = false; return }
        guard let number = Double(draft), number.isFinite,
              editor.values[key]?.intValue == nil || Int(draft) != nil else { error = true; return }
        editor.scalarString(key).wrappedValue = draft; error = false
    }
}

private struct GlanceVisualizerSettingsPreview: View {
    let values: ConfigData
    let palette: [Color]
    let fallback: Color
    var body: some View {
        let count = min(max(values["visualizer-count"]?.intValue ?? 40, 3), 100)
        let width = min(max(values["visualizer-width"]?.doubleValue ?? 200, 30), 600)
        let height = min(max(values["visualizer-height"]?.doubleValue ?? 18, 4), 80)
        let first = PolybarModuleStyle.color(values["visualizer-color"]?.stringValue, palette: palette) ?? fallback
        let last = PolybarModuleStyle.color(values["visualizer-color-2"]?.stringValue, palette: palette) ?? .white
        Canvas { context, size in
            let step = size.width / Double(count)
            for index in 0..<count {
                let phase = Double(index) * 0.7
                let level = max(0.12, min(1, 0.45 + sin(1.2 * 2.3 + phase) * 0.3 + sin(1.2 * 3.7 + phase * 1.3) * 0.2))
                let h = size.height * level
                context.fill(Path(CGRect(x: Double(index) * step, y: size.height - h, width: max(1, step - 1), height: h)), with: .linearGradient(Gradient(colors: [first, last]), startPoint: CGPoint(x: 0, y: size.height), endPoint: .zero))
            }
        }.frame(width: width, height: height)
    }
}
