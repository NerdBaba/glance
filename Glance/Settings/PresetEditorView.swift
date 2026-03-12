import SwiftUI

/// Full preset editor — exposes every appearance setting so users can build
/// a complete custom look without touching TOML.
struct PresetEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: CustomPresetStore

    /// Non-empty when editing an existing preset.
    var editingName: String?

    // MARK: - State

    @State private var presetName: String = ""

    // Style
    @State private var renderingStyle: String = "glass"

    // Shape
    @State private var roundness: Double = 50
    @State private var popupRoundness: Double = 40

    // Border
    @State private var borderWidth: Double = 1.0
    @State private var borderTopOpacity: Double = 0.40
    @State private var borderMidOpacity: Double = 0.15
    @State private var borderBottomOpacity: Double = 0.08

    // Fill & Blur
    @State private var fillOpacity: Double = 0.04
    @State private var popupDarkTint: Double = 0.25

    // Glow
    @State private var glowOpacity: Double = 0.05
    @State private var glowRadius: Double = 2

    // Shadow
    @State private var shadowOpacity: Double = 0.08
    @State private var shadowRadius: Double = 4
    @State private var shadowY: Double = 2

    // Colors
    @State private var foregroundColor: Color = .white
    @State private var accentColor: Color = .white
    @State private var borderColor: Color = .white
    @State private var useGradientBorder: Bool = false
    @State private var borderColor2: Color = .white
    @State private var widgetBackgroundColor: Color = .white
    @State private var glowColor: Color = .white

    private let styles = [
        ("glass", "Glass"),
        ("solid", "Solid"),
        ("minimal", "Minimal"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(editingName != nil ? "Edit Preset" : "Create Preset")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(presetName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Name
                    GroupBox("Name") {
                        TextField("My Custom Preset", text: $presetName)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Rendering Style
                    GroupBox("Rendering Style") {
                        Picker("Style", selection: $renderingStyle) {
                            ForEach(styles, id: \.0) { id, label in
                                Text(label).tag(id)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Shape
                    GroupBox("Shape") {
                        editorSlider("Bar roundness", value: $roundness, range: 0...50, format: "%.0f")
                        editorSlider("Popup roundness", value: $popupRoundness, range: 0...50, format: "%.0f")
                    }

                    // Border
                    GroupBox("Border") {
                        editorSlider("Width", value: $borderWidth, range: 0...3, step: 0.1, format: "%.1f")
                        editorSlider("Top opacity", value: $borderTopOpacity, range: 0...1, step: 0.01, format: "%.2f")
                        editorSlider("Mid opacity", value: $borderMidOpacity, range: 0...1, step: 0.01, format: "%.2f")
                        editorSlider("Bottom opacity", value: $borderBottomOpacity, range: 0...1, step: 0.01, format: "%.2f")
                    }

                    // Fill
                    GroupBox("Fill") {
                        editorSlider("Fill opacity", value: $fillOpacity, range: 0...1, step: 0.01, format: "%.2f")
                        editorSlider("Popup dark tint", value: $popupDarkTint, range: 0...1, step: 0.01, format: "%.2f")
                    }

                    // Glow
                    GroupBox("Glow") {
                        editorSlider("Opacity", value: $glowOpacity, range: 0...1, step: 0.01, format: "%.2f")
                        editorSlider("Radius", value: $glowRadius, range: 0...20, format: "%.0f")
                    }

                    // Shadow
                    GroupBox("Shadow") {
                        editorSlider("Opacity", value: $shadowOpacity, range: 0...0.5, step: 0.01, format: "%.2f")
                        editorSlider("Radius", value: $shadowRadius, range: 0...20, format: "%.0f")
                        editorSlider("Y offset", value: $shadowY, range: 0...10, format: "%.0f")
                    }

                    // Colors
                    GroupBox("Colors") {
                        colorRow("Foreground", color: $foregroundColor)
                        colorRow("Accent", color: $accentColor)
                        colorRow("Border", color: $borderColor)
                        Toggle("Gradient border", isOn: $useGradientBorder)
                        if useGradientBorder {
                            colorRow("Border gradient end", color: $borderColor2)
                        }
                        colorRow("Widget background", color: $widgetBackgroundColor)
                        colorRow("Glow", color: $glowColor)
                    }

                    // Start from preset
                    GroupBox("Start from Built-in") {
                        HStack {
                            Picker("Base", selection: Binding(get: { "" }, set: { loadFromBuiltin($0) })) {
                                Text("— Select —").tag("")
                                ForEach(Preset.allCases, id: \.rawValue) { preset in
                                    Text(preset.rawValue).tag(preset.rawValue)
                                }
                            }
                            .frame(maxWidth: 200)

                            Text("Load all values from a built-in preset as starting point")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 480, height: 650)
        .onAppear { loadExisting() }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func editorSlider(
        _ label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double = 1,
        format: String
    ) -> some View {
        HStack {
            Text(label)
                .frame(width: 130, alignment: .leading)
            Slider(value: value, in: range, step: step)
            Text(String(format: format, value.wrappedValue))
                .monospacedDigit()
                .frame(width: 40, alignment: .trailing)
        }
    }

    @ViewBuilder
    private func colorRow(_ label: String, color: Binding<Color>) -> some View {
        HStack {
            Text(label)
                .frame(width: 130, alignment: .leading)
            ColorPicker("", selection: color, supportsOpacity: false)
                .labelsHidden()
            Text(color.wrappedValue.toHex())
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    // MARK: - Load existing preset for editing

    private func loadExisting() {
        guard let name = editingName, let values = store.load(name: name) else { return }
        presetName = name
        applyValues(values)
    }

    private func loadFromBuiltin(_ rawValue: String) {
        guard let preset = Preset(rawValue: rawValue) else { return }
        let d = preset.defaults
        renderingStyle = d.renderingStyle.rawValue
        roundness = d.roundness
        popupRoundness = d.popupRoundness
        borderWidth = d.borderWidth
        borderTopOpacity = d.borderTopOpacity
        borderMidOpacity = d.borderMidOpacity
        borderBottomOpacity = d.borderBottomOpacity
        fillOpacity = d.fillOpacity
        popupDarkTint = d.popupDarkTint
        glowOpacity = d.glowOpacity
        glowRadius = d.glowRadius
        shadowOpacity = d.shadowOpacity
        shadowRadius = d.shadowRadius
        shadowY = d.shadowY
        foregroundColor = d.foregroundColor
        accentColor = d.accentColor
        borderColor = d.borderColor
        useGradientBorder = d.borderColor2 != nil
        borderColor2 = d.borderColor2 ?? .white
        widgetBackgroundColor = d.widgetBackgroundColor
        glowColor = d.glowColor
    }

    private func applyValues(_ v: [String: String]) {
        if let s = v["rendering-style"] { renderingStyle = s }
        if let s = v["roundness"], let d = Double(s) { roundness = d }
        if let s = v["popup-roundness"], let d = Double(s) { popupRoundness = d }
        if let s = v["border-width"], let d = Double(s) { borderWidth = d }
        if let s = v["border-top-opacity"], let d = Double(s) { borderTopOpacity = d }
        if let s = v["border-mid-opacity"], let d = Double(s) { borderMidOpacity = d }
        if let s = v["border-bottom-opacity"], let d = Double(s) { borderBottomOpacity = d }
        if let s = v["fill-opacity"], let d = Double(s) { fillOpacity = d }
        if let s = v["popup-dark-tint"], let d = Double(s) { popupDarkTint = d }
        if let s = v["glow-opacity"], let d = Double(s) { glowOpacity = d }
        if let s = v["glow-radius"], let d = Double(s) { glowRadius = d }
        if let s = v["shadow-opacity"], let d = Double(s) { shadowOpacity = d }
        if let s = v["shadow-radius"], let d = Double(s) { shadowRadius = d }
        if let s = v["shadow-y"], let d = Double(s) { shadowY = d }
        if let s = v["foreground-color"], let c = AppearanceConfig.parseHex(s) { foregroundColor = c }
        if let s = v["accent-color"], let c = AppearanceConfig.parseHex(s) { accentColor = c }
        if let s = v["border-color"], let c = AppearanceConfig.parseHex(s) { borderColor = c }
        if let s = v["border-color2"], let c = AppearanceConfig.parseHex(s) {
            borderColor2 = c
            useGradientBorder = true
        }
        if let s = v["widget-background-color"], let c = AppearanceConfig.parseHex(s) { widgetBackgroundColor = c }
        if let s = v["glow-color"], let c = AppearanceConfig.parseHex(s) { glowColor = c }
    }

    // MARK: - Save

    private func save() {
        let name = presetName.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "")
            .replacingOccurrences(of: "\0", with: "")
        guard !name.isEmpty, name != ".", name != ".." else { return }

        var values: [String: String] = [
            "rendering-style": renderingStyle,
            "roundness": String(format: "%.0f", roundness),
            "popup-roundness": String(format: "%.0f", popupRoundness),
            "border-width": String(format: "%.1f", borderWidth),
            "border-top-opacity": String(format: "%.2f", borderTopOpacity),
            "border-mid-opacity": String(format: "%.2f", borderMidOpacity),
            "border-bottom-opacity": String(format: "%.2f", borderBottomOpacity),
            "fill-opacity": String(format: "%.2f", fillOpacity),
            "popup-dark-tint": String(format: "%.2f", popupDarkTint),
            "glow-opacity": String(format: "%.2f", glowOpacity),
            "glow-radius": String(format: "%.0f", glowRadius),
            "shadow-opacity": String(format: "%.2f", shadowOpacity),
            "shadow-radius": String(format: "%.0f", shadowRadius),
            "shadow-y": String(format: "%.0f", shadowY),
            "foreground-color": foregroundColor.toHex(),
            "accent-color": accentColor.toHex(),
            "border-color": borderColor.toHex(),
            "widget-background-color": widgetBackgroundColor.toHex(),
            "glow-color": glowColor.toHex(),
        ]
        if useGradientBorder {
            values["border-color2"] = borderColor2.toHex()
        }

        // Delete old name if renamed
        if let old = editingName, old != name {
            store.delete(name: old)
        }
        store.save(name: name, overrides: values)
        dismiss()
    }
}
