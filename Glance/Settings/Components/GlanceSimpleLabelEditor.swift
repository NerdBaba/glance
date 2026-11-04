import SwiftUI

struct GlanceLabelPart: Identifiable {
    enum Kind { case text, value, component, icon, glyph, gap, advanced }
    let id = UUID()
    var kind: Kind
    var value: String

    var serialized: String {
        switch kind {
        case .value: return "%" + value + "%"
        case .component: return "<" + value + ">"
        case .icon: return "{{glance-icon:" + value + "}}"
        case .gap: return "%{O" + value + "px}"
        default: return value
        }
    }

    static func parse(_ text: String) -> [Self] {
        let regex = try! NSRegularExpression(pattern: #"\{\{glance-icon:[^}]+\}\}|%\{[^}]*\}|%[a-zA-Z0-9_-]+%|<[a-zA-Z0-9_-]+>"#)
        var parts: [Self] = []
        var cursor = text.startIndex
        func literal(_ value: String) {
            guard !value.isEmpty else { return }
            var run = ""
            var glyph = false
            for character in value {
                let next = GlanceFontPolicy.isIcon(character) || ["▶", "◀", "⏮", "⏭", "Ⅱ", "♥", "●", "○", "◉", "★"].contains(String(character))
                if !run.isEmpty && next != glyph {
                    parts.append(.init(kind: glyph ? .glyph : .text, value: run)); run = ""
                }
                glyph = next; run.append(character)
            }
            if !run.isEmpty { parts.append(.init(kind: glyph ? .glyph : .text, value: run)) }
        }
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let range = Range(match.range, in: text) else { continue }
            literal(String(text[cursor..<range.lowerBound]))
            let value = String(text[range])
            if value.hasPrefix("{{glance-icon:") { parts.append(.init(kind: .icon, value: String(value.dropFirst(14).dropLast(2)))) }
            else if value.hasPrefix("%{O"), value.hasSuffix("px}"), Double(value.dropFirst(3).dropLast(3)) != nil {
                parts.append(.init(kind: .gap, value: String(value.dropFirst(3).dropLast(3))))
            } else if value.hasPrefix("%{") { parts.append(.init(kind: .advanced, value: value)) }
            else if value.hasPrefix("%") { parts.append(.init(kind: .value, value: String(value.dropFirst().dropLast()))) }
            else { parts.append(.init(kind: .component, value: String(value.dropFirst().dropLast()))) }
            cursor = range.upperBound
        }
        literal(String(text[cursor...]))
        return parts
    }
}

struct GlanceSimpleLabelEditor: View {
    let id: String
    @ObservedObject private var manager = ConfigManager.shared
    @State private var selected = ""
    @State private var parts: [GlanceLabelPart] = []
    @State private var choosingIcon: UUID?
    private var editor: ModuleSettingsEditor { .init(id: id) }
    private var labelKeys: [String] { GlanceFormattingCatalog.components(editor.values).filter { $0.hasPrefix("label") } }
    private var formatKeys: [String] {
        ["format"] + editor.values.keys.filter { ["format-online", "format-offline", "format-volume", "format-muted", "format-connected", "format-disconnected", "format-mounted", "format-unmounted", "format-fail"].contains($0) }.sorted()
    }
    private var primary: String {
        if editor.values["label-song"] != nil { return "label-song" }
        if editor.values["label-connected"] != nil { return "label-connected" }
        if editor.values["label-active"] != nil { return "label-active" }
        return "label"
    }
    private var key: String { selected.isEmpty ? primary : selected }
    private var stored: String { editor.values[key]?.stringValue ?? (key == "format" ? "<label>" : "") }
    private var draft: String { parts.map(\.serialized).joined() }
    private var dirty: Bool { draft != stored }

    static func title(_ key: String) -> String {
        let titles = ["label": "Main label", "label-song": "Track details", "label-connected": "Connected network", "label-disconnected": "Disconnected network", "label-active": "Active space", "label-focused": "Focused space", "label-empty": "Empty space", "label-occupied": "Occupied space", "format": "Module layout", "format-online": "Playing layout", "format-offline": "Idle layout", "format-muted": "Muted layout", "format-volume": "Volume layout", "format-connected": "Connected layout", "format-disconnected": "Disconnected layout"]
        return titles[key] ?? GlanceFormattingCatalog.title(key)
    }

    var body: some View {
        SettingsSection(title: "Custom label builder", subtitle: "Arrange individual text blocks, values, icons, and spacing.", area: .advanced, keywords: [" + key + ", "Apply Label", "Editing", "Module icon", "Previewing changes. Apply Label saves them to your current bar.", "Revert", "Show this label in the module layout", "This field is empty. Add text, a live value, or an icon below.", "format", "format-connected", "format-online", "music", "native-source", "native-symbol-label-prefix", "network", "workspaces"]) {
            Picker("Editing", selection: Binding(get: { key }, set: { next in
                save(); selected = next; parts = GlanceLabelPart.parse(stored)
            })) {
                ForEach(Array(Set(labelKeys + formatKeys + [primary])).sorted(), id: \.self) { key in
                    Text(Self.title(key)).tag(key)
                }
            }
            if parts.isEmpty {
                Text("This field is empty. Add text, a live value, or an icon below.").foregroundStyle(.secondary)
            }
            ForEach(Array(parts.enumerated()).filter { $0.element.kind != .advanced }, id: \.element.id) { index, part in
                partRow(part, index: index)
            }
            HStack {
                addMenu
                Spacer()
                Button("Revert") { parts = GlanceLabelPart.parse(stored) }.disabled(!dirty)
                Button("Apply Label") { save() }.buttonStyle(.borderedProminent).disabled(!dirty)
            }
            GlanceModulePreview(values: editor.values, field: key, draft: draft)
            if dirty { Text("Previewing changes. Apply Label saves them to your current bar.").font(.caption).foregroundStyle(.secondary) }
            if !key.hasPrefix("format") {
                GlanceSymbolPickerButton(selection: editor.string("native-symbol-label-prefix", removeEmpty: true), title: "Module icon")
                if editor.values["native-source"]?.stringValue != "workspaces",
                   !formatKeys.contains(where: { editor.values[$0]?.stringValue?.contains("<" + key + ">") == true }) {
                    Button("Show this label in the module layout") {
                        save()
                        let format = editor.values["native-source"]?.stringValue == "music" ? "format-online"
                            : editor.values["native-source"]?.stringValue == "network" ? "format-connected" : "format"
                        let existing = editor.values[format]?.stringValue ?? ""
                        editor.scalarString(format).wrappedValue = existing + (existing.isEmpty ? "" : " ") + "<" + key + ">"
                    }
                }
            }
        }
        .onAppear { parts = GlanceLabelPart.parse(stored) }
        .onChange(of: stored) { old, new in
            if draft == old { parts = GlanceLabelPart.parse(new) }
        }
        .popover(isPresented: Binding(get: { choosingIcon != nil }, set: { if !$0 { choosingIcon = nil } })) {
            IconPickerView(selectedIcon: .constant(""), recentIcons: [], onIconSelected: { symbol in
                if let index = parts.firstIndex(where: { $0.id == choosingIcon }) {
                    parts[index].kind = .icon; parts[index].value = symbol
                }
                choosingIcon = nil
            }, onDismiss: { choosingIcon = nil })
        }
    }

    private var addMenu: some View {
        Menu("Add…", systemImage: "plus.circle") {
            Button("Text") { parts.append(.init(kind: .text, value: "Text")) }
            Menu("Live value") {
                ForEach(GlanceFormattingCatalog.tokenNames(source: editor.values["native-source"]?.stringValue), id: \.self) { name in
                    Button(GlanceFormattingCatalog.tokenTitle(name).replacingOccurrences(of: "  %" + name + "%", with: "")) { parts.append(.init(kind: .value, value: name)) }
                }
            }
            if key.hasPrefix("format") {
                Menu("Component") {
                    ForEach(GlanceFormattingCatalog.components(editor.values) + ["label-prefix", "label-suffix"], id: \.self) { name in
                        Button(Self.title(name)) { parts.append(.init(kind: .component, value: name)) }
                    }
                }
            }
            Button("Icon…") {
                let part = GlanceLabelPart(kind: .icon, value: "star")
                parts.append(part); choosingIcon = part.id
            }
            Button("Spacing") { parts.append(.init(kind: .gap, value: "6")) }
        }
    }

    private func valueBinding(_ index: Int) -> Binding<String> {
        Binding(get: { parts.indices.contains(index) ? parts[index].value : "" }, set: { if parts.indices.contains(index) { parts[index].value = $0 } })
    }

    private func partRow(_ part: GlanceLabelPart, index: Int) -> some View {
        HStack(spacing: 10) {
            partControl(part, index: index).frame(maxWidth: .infinity, alignment: .leading)
            Button { move(index, direction: -1) } label: { Image(systemName: "arrow.up") }
                .disabled(neighbor(index, direction: -1) == nil).help("Move earlier").accessibilityLabel("Move earlier")
            Button { move(index, direction: 1) } label: { Image(systemName: "arrow.down") }
                .disabled(neighbor(index, direction: 1) == nil).help("Move later").accessibilityLabel("Move later")
            Button { parts.remove(at: index) } label: { Image(systemName: "xmark") }
                .help("Remove block").accessibilityLabel("Remove block")
        }
        .padding(9).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder private func partControl(_ part: GlanceLabelPart, index: Int) -> some View {
        switch part.kind {
        case .text:
            HStack { Text("Text").foregroundStyle(.secondary); TextField("Text", text: valueBinding(index)).textFieldStyle(.roundedBorder) }
        case .value:
            Picker("Live value", selection: valueBinding(index)) {
                ForEach(Array(Set(GlanceFormattingCatalog.tokenNames(source: editor.values["native-source"]?.stringValue) + [part.value])).sorted(), id: \.self) { name in
                    Text(GlanceFormattingCatalog.tokenTitle(name).replacingOccurrences(of: "  %" + name + "%", with: "")).tag(name)
                }
            }
        case .component:
            Picker("Component", selection: valueBinding(index)) {
                ForEach(Array(Set(GlanceFormattingCatalog.components(editor.values) + ["label-prefix", "label-suffix", part.value])).sorted(), id: \.self) { name in Text(Self.title(name)).tag(name) }
            }
        case .icon:
            Button { choosingIcon = part.id } label: {
                Label { Text("Choose icon…") } icon: { Image(nsImage: GlanceInlineIcons.image(part.value, size: 18) ?? NSImage()) }
            }
        case .glyph:
            HStack {
                GlanceModulePreview(values: editor.values, field: key, draft: part.value).frame(maxWidth: 100)
                Button("Choose icon…") { choosingIcon = part.id }
            }
        case .gap:
            HStack {
                Text("Spacing")
                Slider(value: Binding(get: { Double(part.value) ?? 6 }, set: { parts[index].value = String(Int($0)) }), in: 0...40, step: 1)
                Text("\(part.value) pt").monospacedDigit().frame(width: 50)
            }
        case .advanced:
            Label("Existing style or action", systemImage: "slider.horizontal.3")
                .foregroundStyle(.secondary).help("Preserved unchanged. Edit its syntax under Advanced formatting.")
        }
    }

    private func neighbor(_ index: Int, direction: Int) -> Int? {
        var candidate = index + direction
        while parts.indices.contains(candidate) {
            if parts[candidate].kind != .advanced { return candidate }
            candidate += direction
        }
        return nil
    }

    private func move(_ index: Int, direction: Int) {
        if let target = neighbor(index, direction: direction) { parts.swapAt(index, target) }
    }

    private func save() {
        guard dirty else { return }
        editor.scalarString(key).wrappedValue = draft
    }
}
