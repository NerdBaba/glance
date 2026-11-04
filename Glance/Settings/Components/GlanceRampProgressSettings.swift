import SwiftUI

struct GlanceRampProgressSettings: View {
    let id: String
    @ObservedObject private var manager = ConfigManager.shared
    private var editor: ModuleSettingsEditor { .init(id: id) }
    private var components: [String] { GlanceFormattingCatalog.components(editor.values).filter { $0.hasPrefix("ramp-") || $0.hasPrefix("bar-") || $0.hasPrefix("animation-") } }
    var body: some View {
        if !components.isEmpty {
            SettingsSection(title: "Ramps, progress & animation", subtitle: "Ramps choose an icon by percentage. Progress bars draw filled and empty segments. Insert these components into Layout to display them.", keywords: [" + component + ", " + key }.map { ", " + part + ", " + part, title: part.capitalized + ", " color", "%.0f ms", ").last.map(String.init) ?? ", ", value: editor.integer(component + ", "-background", "-font", "-foreground", "-foreground-", "-framerate", "-gradient", "-padding", "-width", ": .string(", "Add gradient color", "Add level", "Component background", "Component text color", "Frame duration", "Gradient", "Gradient color ", "Level ", "Level color", "Remove", "Remove level", "animation-", "bar-", "empty", "fill", "format", "indicator"]) {
                ForEach(components, id: \.self) { component in
                    DisclosureGroup(GlanceFormattingCatalog.title(component)) {
                        VStack(alignment: .leading, spacing: 14) {
                            GlanceModulePreview(values: editor.values.merging(["format": .string("<" + component + ">"), "format-prefix": .string(""), "format-suffix": .string("")]) { _, new in new })
                            if component.hasPrefix("bar-") {
                                Stepper("Segments: \(editor.integer(component + "-width", default: 10).wrappedValue)", value: editor.integer(component + "-width", default: 10), in: 1...256)
                                ForEach(["fill", "empty", "indicator"], id: \.self) { part in
                                    GlanceComponentIconControl(id: id, key: component + "-" + part, title: part.capitalized + " segment")
                                    ModuleColorControl(label: part.capitalized + " color", value: editor.string(component + "-" + part + "-foreground", removeEmpty: true))
                                }
                                Toggle("Gradient", isOn: editor.bool(component + "-gradient"))
                                ForEach(editor.values.keys.filter { $0.hasPrefix(component + "-foreground-") }.sorted(), id: \.self) { key in
                                    HStack { ModuleColorControl(label: "Gradient color " + (key.split(separator: "-").last.map(String.init) ?? ""), value: editor.string(key, removeEmpty: true))
                                        Button("Remove", role: .destructive) { manager.removeConfigValue(key: "widgets.\(id).\(key)") }
                                    }
                                }
                                Button("Add gradient color") { addColor(component) }
                            } else {
                                ForEach(frames(component), id: \.self) { key in
                                    GlanceComponentIconControl(id: id, key: key, title: "Level " + (key.split(separator: "-").last.map(String.init) ?? ""))
                                    ModuleColorControl(label: "Level color", value: editor.string(key + "-foreground", removeEmpty: true))
                                    Button("Remove level", role: .destructive) {
                                        manager.removeConfigValues(keys: editor.values.keys.filter { $0 == key || $0.hasPrefix(key + "-") || $0 == "native-symbol-" + key }.map { "widgets.\(id)." + $0 })
                                    }.disabled(frames(component).count <= 1)
                                }
                                Button("Add level") { addFrame(component) }
                                if component.hasPrefix("animation-") {
                                    ModuleSlider(label: "Frame duration", value: editor.number(component + "-framerate", default: 1000), range: 50...5000, format: "%.0f ms")
                                }
                            }
                            ModuleColorControl(label: "Component text color", value: editor.string(component + "-foreground", removeEmpty: true))
                            ModuleColorControl(label: "Component background", value: editor.string(component + "-background", removeEmpty: true))
                            GlanceModuleOptionControl(id: id, key: component + "-font")
                            Stepper("Padding: \(editor.integer(component + "-padding", default: 0).wrappedValue)", value: editor.integer(component + "-padding", default: 0), in: 0...32)
                        }.padding(.top, 12)
                    }
                }
            }
        }
    }
    private func frames(_ component: String) -> [String] {
        editor.values.keys.filter { $0.hasPrefix(component + "-") && Int($0.dropFirst(component.count + 1)) != nil }
            .sorted { (Int($0.dropFirst(component.count + 1)) ?? 0) < (Int($1.dropFirst(component.count + 1)) ?? 0) }
    }
    private func addFrame(_ component: String) {
        let next = (frames(component).compactMap { Int($0.dropFirst(component.count + 1)) }.max() ?? -1) + 1
        manager.updateConfigValue(key: "widgets.\(id).\(component)-\(next)", newValue: ModuleSettingsEditor.quoted("●"))
    }
    private func addColor(_ component: String) {
        let prefix = component + "-foreground-"
        let next = (editor.values.keys.filter { $0.hasPrefix(prefix) }.compactMap { Int($0.dropFirst(prefix.count)) }.max() ?? -1) + 1
        manager.updateConfigValue(key: "widgets.\(id).\(prefix)\(next)", newValue: ModuleSettingsEditor.quoted("pywal:\(next % 8 + 1)"))
    }
}
