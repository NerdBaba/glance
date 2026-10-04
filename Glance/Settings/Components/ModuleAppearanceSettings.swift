import SwiftUI

struct ModuleAppearanceSettings: View {
  let id: String
  @ObservedObject private var configManager = ConfigManager.shared
  @State private var showBorder = false
  @State private var showGroup = false
  private var editor: ModuleSettingsEditor { .init(id: id) }

  var body: some View {
    colors
    spacing
    typography
    SettingsSection(title: "Advanced appearance") {
      DisclosureGroup("Segment border", isExpanded: $showBorder) {
        VStack(alignment: .leading, spacing: 16) {
          ModuleColorControl(
            label: "Outline", value: editor.string("format-border-color", removeEmpty: true))
          ModuleSlider(
            label: "Outline width", value: editor.number("format-border-width", default: 0),
            range: 0...8, step: 0.5, format: "%.1f pt")
        }.padding(.top, 12)
      }
      DisclosureGroup("Group outline & width", isExpanded: $showGroup) {
        VStack(alignment: .leading, spacing: 16) {
          Text("These options affect a pill group when this module is its first widget.")
            .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
          ModuleColorControl(
            label: "Group outline", value: editor.string("group-border-color", removeEmpty: true))
          ModuleSlider(
            label: "Outline width", value: editor.number("group-border-width", default: 0),
            range: 0...8, step: 0.5, format: "%.1f pt")
          Toggle("Keep group at configured width", isOn: editor.bool("group-fixed-width"))
        }.padding(.top, 12)
      }
    }
  }

  private var colors: some View {
    SettingsSection(
      title: "Colors", subtitle: "Inherit the bar palette or give this module its own colors."
    ) {
      ModuleColorControl(
        label: "Background", value: editor.string("format-background", removeEmpty: true))
      ModuleColorControl(
        label: "Foreground", value: editor.string("format-foreground", removeEmpty: true))
      if let background = editor.values["format-background"]?.stringValue,
        !["", "none", "transparent"].contains(background)
      {
        ModuleSlider(
          label: "Background opacity",
          value: editor.number("format-background-opacity", default: 1), range: 0...1, step: 0.01,
          format: "%.2f")
      }
    }
  }

  private var spacing: some View {
    let padding =
      editor.values["format-padding"]?.doubleValue
      ?? (editor.values["format-background"] == nil ? 0 : 4)
    return SettingsSection(title: "Size & spacing") {
      ModuleSlider(
        label: "Corner radius", value: editor.number("format-radius", default: 0), range: 0...40)
      ModuleSlider(
        label: "Horizontal padding", value: editor.number("format-padding", default: padding),
        range: 0...48)
      HStack(alignment: .top, spacing: 24) {
        ModuleSlider(
          label: "Left padding", value: editor.number("format-padding-left", default: padding),
          range: 0...80)
        ModuleSlider(
          label: "Right padding", value: editor.number("format-padding-right", default: padding),
          range: 0...80)
      }
      ModuleSlider(
        label: "Minimum width", value: editor.number("format-min-width", default: 0), range: 0...320
      )
      Picker("Content alignment", selection: editor.string("format-alignment", default: "center")) {
        Text("Left").tag("left")
        Text("Center").tag("center")
        Text("Right").tag("right")
      }.pickerStyle(.menu)
      ModuleSlider(
        label: "Vertical offset", value: editor.number("format-offset-y", default: 0),
        range: -12...12)
    }
  }

  private var typography: some View {
    let appearance = configManager.config.appearance
    let font = appearance.useSingleFont ? appearance.barFont : appearance.widgetFont
    return SettingsSection(
      title: "Typography", subtitle: "Leave the font name empty to use the global font."
    ) {
      SettingsTextField(
        label: "Font name", value: editor.string("format-font-name", removeEmpty: true),
        prompt: "Use global font")
      ModuleSlider(
        label: "Text size", value: editor.number("format-font-size", default: font.fontSize),
        range: 5...72, step: 0.5, format: "%.1f pt")
      Picker(
        "Weight",
        selection: Binding<Int>(
          get: { editor.values["format-font-weight"]?.intValue ?? -1 },
          set: { value in
            if value == -1 {
              configManager.removeConfigValue(key: "widgets.\(id).format-font-weight")
            } else {
              editor.integer("format-font-weight", default: -1).wrappedValue = value
            }
          }
        )
      ) {
        Text("Use global weight").tag(-1)
        ForEach(
          Array(
            [
              "Thin", "Ultra light", "Light", "Regular", "Medium", "Semibold", "Bold", "Heavy",
              "Black",
            ].enumerated()), id: \.offset
        ) { index, title in
          Text(title).tag(index)
        }
      }.pickerStyle(.menu)
      ModuleSlider(
        label: "Letter spacing", value: editor.number("format-tracking", default: 0), range: -3...6,
        step: 0.1, format: "%.1f pt")
    }
  }
}

struct ModuleColorControl: View {
  let label: String
  @Binding var value: String
  @ObservedObject private var configManager = ConfigManager.shared

  private var paletteIndex: Int? {
    let parts = value.lowercased().split(separator: ":")
    guard parts.count == 2, ["pywal", "pywal-index"].contains(String(parts[0])) else { return nil }
    return Int(parts[1])
  }

  private var mode: String {
    if value.isEmpty || ["none", "transparent"].contains(value.lowercased()) { return "inherit" }
    return paletteIndex == nil ? "custom" : "pywal"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Picker(
        label,
        selection: Binding(
          get: { mode },
          set: { mode in
            switch mode {
            case "pywal": value = "pywal:8"
            case "custom": value = "#bdbdbd"
            default: value = ""
            }
          })
      ) {
        Text("Inherit").tag("inherit")
        Text("Pywal palette").tag("pywal")
        Text("Custom color").tag("custom")
      }.pickerStyle(.menu)
      if mode == "pywal" {
        LazyVGrid(
          columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 8), spacing: 8
        ) {
          ForEach(0..<16, id: \.self) { index in
            Button {
              value = "pywal:\(index)"
            } label: {
              VStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 5)
                  .fill(color(index))
                  .frame(height: 24)
                  .overlay(
                    RoundedRectangle(cornerRadius: 5).strokeBorder(
                      paletteIndex == index ? Color.primary : .clear, lineWidth: 2))
                Text(String(index)).font(.caption2).monospacedDigit()
              }
              .padding(3)
              .background(
                paletteIndex == index ? Color.accentColor.opacity(0.12) : .clear,
                in: RoundedRectangle(cornerRadius: 7))
            }.buttonStyle(.plain).accessibilityLabel("\(label), Pywal color \(index)")
          }
        }
      } else if mode == "custom" {
        HStack(spacing: 16) {
          ColorPicker(
            "Color",
            selection: Binding(
              get: { PolybarModuleStyle.color(value, palette: []) ?? .white },
              set: { value = $0.toHex() }
            ), supportsOpacity: false)
          SettingsTextField(label: "Hex value", value: $value, prompt: "#RRGGBB")
        }
      }
    }
  }

  private func color(_ index: Int) -> Color {
    let colors = configManager.config.pywalColors?.colors ?? []
    return colors.indices.contains(index) ? colors[index] : .gray
  }
}

struct ModuleIconSettings: View {
  let id: String
  private var editor: ModuleSettingsEditor { .init(id: id) }
  private var iconFontName: String? {
    editor.values["icon-font-name"]?.stringValue
      ?? editor.values["format-font-name"]?.stringValue
      ?? ConfigManager.shared.config.appearance.widgetFont.fontName
  }

  var body: some View {
    if [
      "default.mediacontrols", "default.volume", "default.power", "default.launcher",
      "default.network", "default.time",
    ].contains(id) {
      SettingsSection(
        title: "Icons", subtitle: "Custom glyphs use the icon font. Empty glyphs use system icons."
      ) {
        if id == "default.mediacontrols" {
          HStack(alignment: .top, spacing: 24) {
            glyph("Previous", key: "icon-prev")
            glyph("Play", key: "icon-play")
          }
          HStack(alignment: .top, spacing: 24) {
            glyph("Pause", key: "icon-pause")
            glyph("Next", key: "icon-next")
          }
          ModuleSlider(
            label: "Control spacing", value: editor.number("control-spacing", default: 5),
            range: 0...40)
        } else if id == "default.volume" {
          glyph("Low volume", key: "ramp-volume-0")
          glyph("Medium volume", key: "ramp-volume-1")
          glyph("High volume", key: "ramp-volume-2")
          ModuleSlider(
            label: "Icon spacing", value: editor.number("content-spacing", default: 5),
            range: 0...40)
        } else {
          glyph("Custom glyph", key: "glyph")
        }
        SettingsTextField(
          label: "Icon font", value: editor.string("icon-font-name", removeEmpty: true),
          prompt: "Use module font")
        ModuleSlider(
          label: "Icon size", value: editor.number("icon-font-size", default: 12), range: 5...32,
          step: 0.5, format: "%.1f pt")
        ModuleSlider(
          label: "Vertical offset", value: editor.number("icon-offset-y", default: 0),
          range: -10...10)
      }
    }
  }

  private func glyph(_ label: String, key: String) -> some View {
    SettingsTextField(
      label: label, value: editor.string(key, removeEmpty: true), fontName: iconFontName)
  }
}
