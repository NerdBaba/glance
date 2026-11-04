import SwiftUI

struct GlanceWorkspaceIconControl: View {
    let id: String
    let key: String
    @ObservedObject private var manager = ConfigManager.shared
    @State private var space = ""
    @State private var glyph = ""
    @State private var pickingIcon = false
    @FocusState private var focused: Bool
    private var editor: ModuleSettingsEditor { .init(id: id) }
    private var value: String { editor.values[key]?.stringValue ?? "" }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Space icon")
                Spacer()
                Button("Choose icon…") { pickingIcon = true }
            }
            HStack {
                TextField("Space ID", text: $space).frame(width: 100)
                TextField("Glyph or text", text: $glyph)
            }.textFieldStyle(.roundedBorder).focused($focused)
                .onSubmit { commit() }.onChange(of: focused) { _, focus in if !focus { commit() } }
            GlanceModulePreview(values: editor.values, field: "label-preview", draft: glyph)
            Text("This icon replaces %icon% for the selected space. Space IDs match your workspace provider.")
                .font(.caption).foregroundStyle(.secondary)
        }.onAppear { sync() }.onChange(of: value) { _, _ in if !focused { sync() } }
        .popover(isPresented: $pickingIcon) {
            IconPickerView(selectedIcon: .constant(""), recentIcons: [], onIconSelected: {
                glyph = "{{glance-icon:" + $0 + "}}"; commit(); pickingIcon = false
            }, onDismiss: { pickingIcon = false })
        }
    }
    private func sync() {
        let parts = value.split(separator: ";", maxSplits: 1, omittingEmptySubsequences: false)
        space = parts.first.map(String.init) ?? ""
        glyph = parts.count > 1 ? String(parts[1]) : ""
    }
    private func commit() {
        guard !space.isEmpty, !space.contains(";"), !space.contains("\n") else { return }
        let next = space + ";" + glyph
        if value != next { editor.string(key).wrappedValue = next }
    }
}
