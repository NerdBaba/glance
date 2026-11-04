import SwiftUI
import TOMLDecoder

/// Advanced values are validated and canonicalized before being written, so a
/// multiline draft cannot introduce additional module settings accidentally.
enum GlanceOptionValue {
    static func serialized(_ value: TOMLValue) -> String {
        switch value {
        case .string(let text): return ModuleSettingsEditor.quoted(text)
        case .bool(let value): return value ? "true" : "false"
        case .int(let value): return String(value)
        case .double(let value): return String(value)
        case .array(let values): return "[" + values.map(serialized).joined(separator: ", ") + "]"
        case .dictionary(let values): return "{ " + values.keys.sorted().map { ModuleSettingsEditor.quoted($0) + " = " + serialized(values[$0]!) }.joined(separator: ", ") + " }"
        case .null: return ""
        }
    }
    static func validated(_ draft: String) throws -> String {
        let values = try TOMLDecoder().decode(ConfigData.self, from: "value = " + draft)
        guard values.count == 1, let value = values["value"], isFinite(value) else { throw CocoaError(.coderInvalidValue) }
        return serialized(value)
    }
    private static func isFinite(_ value: TOMLValue) -> Bool {
        switch value {
        case .double(let value): return value.isFinite
        case .array(let values): return values.allSatisfy(isFinite)
        case .dictionary(let values): return values.values.allSatisfy(isFinite)
        case .null: return false
        default: return true
        }
    }
}

struct GlanceStructuredOptionField: View {
    let id: String
    let key: String
    @State private var draft = ""
    @State private var error = false
    @FocusState private var focused: Bool
    @ObservedObject private var manager = ConfigManager.shared
    private var editor: ModuleSettingsEditor { .init(id: id) }
    private var value: String { GlanceOptionValue.serialized(editor.values[key] ?? .null) }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(GlanceFormattingCatalog.title(key))
            TextField("TOML value", text: $draft, axis: .vertical).lineLimit(1...6)
                .font(.system(size: 14, design: .monospaced)).textFieldStyle(.roundedBorder).focused($focused)
                .onSubmit { commit() }.onChange(of: focused) { _, focus in if !focus { commit() } }
            if error { Text("Enter a valid TOML value. The previous setting is still applied.").foregroundStyle(.red).font(.caption) }
            else { Text("Array or table in TOML syntax. Return or leaving the field applies it.").foregroundStyle(.secondary).font(.caption) }
        }.onAppear { draft = value }.onChange(of: value) { _, new in if !focused { draft = new } }
    }
    private func commit() {
        guard draft != value else { return }
        do {
            let next = try GlanceOptionValue.validated(draft)
            manager.updateConfigValue(key: "widgets.\(id).\(key)", newValue: next)
            error = false
        } catch { self.error = true }
    }
}
