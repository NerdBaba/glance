import SwiftUI

struct GlanceTransitionSettings: View {
    let id: String
    @ObservedObject private var manager = ConfigManager.shared
    private var editor: ModuleSettingsEditor { .init(id: id) }
    private var shape: String { editor.values["native-transition-shape"]?.stringValue ?? "original" }
    private var height: Double { manager.config.experimental.foreground.resolveHeight() }
    private let shapes = [("arrow-right", "Arrow right"), ("arrow-left", "Arrow left"), ("slash-right", "Slope right"), ("slash-left", "Slope left"), ("round-right", "Round right"), ("round-left", "Round left"), ("line", "Separator"), ("none", "None")]

    var body: some View {
        SettingsSection(title: "Transition", subtitle: "Connect the colors on either side with a shape. No glyph or font index editing needed.", keywords: ["Color after", "Color before", "Height", "Match neighboring modules", "Preset’s original shape", "Restore preset shape", "Shape", "Width", "eyedropper", "format-background", "format-foreground", "label-background", "label-foreground", "line", "native-transition-shape", "none", "original", "pywal:0", "pywal:15", "transition-height", "transition-left-color", "transition-right-color", "transition-width"]) {
            GlanceModulePreview(values: editor.values)
            Picker("Shape", selection: editor.string("native-transition-shape", default: "original")) {
                Text("Preset’s original shape").tag("original")
                ForEach(shapes, id: \.0) { item in Text(item.1).tag(item.0) }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 95))], spacing: 10) {
                ForEach(shapes.filter { !["none", "line"].contains($0.0) }, id: \.0) { item in
                    Button { editor.string("native-transition-shape").wrappedValue = item.0 } label: {
                        VStack(spacing: 5) {
                            GlanceTransitionShape(kind: item.0).fill(Color.accentColor).frame(width: 28, height: 24)
                                .background(Color.secondary.opacity(0.15)).clipped()
                            Text(item.1).font(.caption)
                        }.frame(maxWidth: .infinity).padding(8)
                    }
                    .buttonStyle(.plain)
                    .background(shape == item.0 ? Color.accentColor.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 8))
                    .accessibilityLabel(item.1)
                }
            }
            ModuleColorControl(label: "Color before", value: editor.string("transition-left-color", default: editor.values["label-background"]?.stringValue ?? editor.values["format-background"]?.stringValue ?? "pywal:0"))
            ModuleColorControl(label: "Color after", value: editor.string("transition-right-color", default: editor.values["label-foreground"]?.stringValue ?? editor.values["format-foreground"]?.stringValue ?? "pywal:15"))
            Button("Match neighboring modules", systemImage: "eyedropper") { matchNeighbors() }
            if shape != "original" && shape != "none" {
                let size = GlanceTransitionWidget.dimensions(editor.values, fallbackHeight: height)
                ModuleSlider(label: "Width", value: editor.number("transition-width", default: size.width), range: 1...100)
                ModuleSlider(label: "Height", value: editor.number("transition-height", default: size.height), range: 8...160)
            }
            Button("Restore preset shape") {
                manager.removeConfigValues(keys: ["native-transition-shape", "transition-width", "transition-height", "transition-left-color", "transition-right-color"].map { "widgets.\(id)." + $0 })
            }
        }
        SettingsSection(title: "Original transition formatting", area: .advanced, keywords: ["Original glyph", "label"]) {
            GlanceFormattedField(id: id, key: "label", title: "Original glyph")
            ModuleAppearanceSettings(id: id).environment(\.widgetSettingsArea, nil)
        }
    }

    private func matchNeighbors() {
        let items = manager.config.rootToml.widgets?.displayed ?? []
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        func background(_ items: [TomlWidgetItem]) -> String {
            for item in items where !["spacer", "divider"].contains(item.id) {
                let values = manager.resolvedWidgetConfig(for: item)
                guard !GlanceTransitionWidget.isDecoration(values) else { continue }
                return values["format-background"]?.stringValue ?? values["label-background"]?.stringValue ?? "pywal:0"
            }
            return "pywal:0"
        }
        manager.updateConfigValues(pairs: [
            (key: "widgets.\(id).transition-left-color", value: ModuleSettingsEditor.quoted(background(Array(items[..<index].reversed())))),
            (key: "widgets.\(id).transition-right-color", value: ModuleSettingsEditor.quoted(background(Array(items.dropFirst(index + 1)))))
        ])
    }
}
