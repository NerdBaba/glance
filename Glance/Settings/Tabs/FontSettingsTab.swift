import SwiftUI

struct FontSettingsTab: View {
  @ObservedObject var configManager = ConfigManager.shared
  @State private var isSyncing = false

  // Single font state (applies to both bar and widgets)
  @State private var fontName: String?
  @State private var fontSize: Double
  @State private var fontWeight: Int

  init() {
    let appearance = ConfigManager.shared.config.appearance

    // Use bar font as the primary font
    _fontName = State(initialValue: appearance.barFont.fontName)
    _fontSize = State(initialValue: Double(appearance.barFont.fontSize))
    _fontWeight = State(initialValue: appearance.barFont.weight.toInt())
  }

  var body: some View {
    SettingsPage {
      SettingsPageHeader(
        title: "Fonts",
        summary:
          "Change the text font across your preset. Icon fonts and transition shapes are preserved.")
      SettingsSection(title: "Global font", keywords: ["%.1f", "Choose Font…", "Font", "Preview", "Reset to System Font", "Size", "Use global font for preset text", "Use this font in all text modules", "Weight", "appearance.override-module-fonts", "bar-font-size", "bar-font-weight", "false", "true", "widget-font-size", "widget-font-weight"]) {
        VStack(alignment: .leading, spacing: 12) {
          Toggle("Use global font for preset text", isOn: Binding(get: {
            configManager.config.appearance.overrideModuleFonts
          }, set: { value in
            configManager.updateConfigValue(key: "appearance.override-module-fonts", newValue: value ? "true" : "false")
          }))
          Text("Choosing a font, size, or weight enables this automatically. Turn it off to restore the preset’s original typography.")
            .font(.caption).foregroundStyle(.secondary)
          Button("Use this font in all text modules") {
            let keys = SettingsModule.all(config: configManager.config).map { "widgets.\($0.id).font-use-global" }
            configManager.removeConfigValues(keys: keys)
            configManager.updateConfigValue(key: "appearance.override-module-fonts", newValue: "true")
          }
          HStack {
            Text("Font")
              .fontWeight(.medium)
            Spacer()
            Button("Choose Font…") {
              openNativeFontPicker()
            }
            .buttonStyle(.borderedProminent)
          }

          fontPreviewRow(
            fontName: fontName,
            fontSize: fontSize,
            weight: fontWeight,
            label: "Preview"
          )

          HStack {
            Text("Size")
            Slider(value: $fontSize, in: 8...24, step: 0.5)
              .frame(width: 150)
              .onChange(of: fontSize) { _, newValue in
                guard !isSyncing else { return }
                applyGlobalFont([("bar-font-size", String(newValue)), ("widget-font-size", String(newValue))])
              }
            Text("\(fontSize, specifier: "%.1f") pt")
              .monospacedDigit()
              .frame(width: 50)
          }

          HStack {
            Text("Weight")
            Picker("Weight", selection: $fontWeight) {
              ForEach(0...8, id: \.self) { weight in
                Text(weightName(for: weight)).tag(weight)
              }
            }
            .pickerStyle(.menu)
            .onChange(of: fontWeight) { _, newValue in
              guard !isSyncing else { return }
              applyGlobalFont([("bar-font-weight", String(newValue)), ("widget-font-weight", String(newValue))])
            }
          }

          if fontName != nil {
            Button("Reset to System Font") {
              resetFont()
            }
            .buttonStyle(.borderless)
          }
        }
        .padding(.vertical, 8)
      }

      SettingsSection(title: "Reset", keywords: ["Reset Font to Default"]) {
        Button("Reset Font to Default") {
          resetFont()
        }
        .buttonStyle(.borderless)
      }
    }
    .onReceive(configManager.$config) { _ in
      syncFromConfig()
    }
  }

  // MARK: - Font Preview

  @ViewBuilder
  private func fontPreviewRow(
    fontName: String?,
    fontSize: Double,
    weight: Int,
    label: String
  ) -> some View {
    let previewText = fontName ?? "System Font"
    let weightValue = Font.Weight.fromInt(weight) ?? .regular
    let font =
      fontName.map { Font.custom($0, size: fontSize).weight(weightValue) }
      ?? Font.system(size: fontSize, weight: weightValue)

    HStack {
      Text(label)
        .foregroundStyle(.secondary)
      Text(previewText)
        .font(font)
        .lineLimit(1)
      Spacer()
    }
    .frame(height: 24)
  }

  // MARK: - Native Font Panel

  private func openNativeFontPicker() {
    guard let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }) else {
      print("No window available for font panel")
      return
    }

    FontManager.shared.openFontPanel(
      initialFontName: fontName,
      initialSize: CGFloat(fontSize),
      parentWindow: window
    ) { fontName, fontSize, weight in
      // Update state on main thread - allow continuous updates
      DispatchQueue.main.async { [self] in
        // Skip if syncing to prevent loops
        if self.isSyncing { return }

        self.isSyncing = true
        defer {
          self.isSyncing = false
        }

        // Validate font name (check for valid fonts)
        let validFontName = fontName.isEmpty ? "" : fontName

        self.fontName = validFontName.isEmpty ? nil : validFontName
        self.fontSize = Double(fontSize)
        self.fontWeight = Int(weight)

        self.applyGlobalFont([
          ("bar-font-name", validFontName), ("bar-font-size", String(Double(fontSize))), ("bar-font-weight", String(Int(weight))),
          ("widget-font-name", validFontName), ("widget-font-size", String(Double(fontSize))), ("widget-font-weight", String(Int(weight)))
        ])
      }
    }
  }

  // MARK: - Actions

  private func resetFont() {
    isSyncing = true
    defer { isSyncing = false }

    fontName = nil
    fontSize = 13
    fontWeight = 4  // medium

    applyGlobalFont([
      ("bar-font-name", ""), ("bar-font-size", "13"), ("bar-font-weight", "4"),
      ("widget-font-name", ""), ("widget-font-size", "13"), ("widget-font-weight", "4")
    ])
  }

  private func applyGlobalFont(_ values: [(String, String)]) {
    configManager.updateConfigValues(pairs: values.map { (key: "appearance." + $0.0, value: $0.1) }
      + [(key: "appearance.override-module-fonts", value: "true")])
  }

  // MARK: - Helpers

  private func weightName(for value: Int) -> String {
    switch value {
    case 0: return "Thin"
    case 1: return "Ultra Light"
    case 2: return "Light"
    case 3: return "Regular"
    case 4: return "Medium"
    case 5: return "Semibold"
    case 6: return "Bold"
    case 7: return "Heavy"
    case 8: return "Black"
    default: return "Regular"
    }
  }

  private func syncFromConfig() {
    guard !isSyncing else { return }
    let appearance = configManager.config.appearance

    // Only update if values are actually different (prevents fighting with user input)
    if fontName != appearance.barFont.fontName {
      fontName = appearance.barFont.fontName
    }
    if abs(fontSize - Double(appearance.barFont.fontSize)) > 0.1 {
      fontSize = Double(appearance.barFont.fontSize)
    }
    if fontWeight != appearance.barFont.weight.toInt() {
      fontWeight = appearance.barFont.weight.toInt()
    }
  }
}

#Preview {
  FontSettingsTab()
}
