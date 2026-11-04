import SwiftUI

/// Everyday choices write the existing format schema. Imported layouts remain
/// intact until the person explicitly chooses a new presentation.
struct GlanceQuickContentSettings: View {
  let id: String
  @ObservedObject private var manager = ConfigManager.shared
  private var editor: ModuleSettingsEditor { .init(id: id) }
  private var source: String { editor.values["native-source"]?.stringValue ?? "command" }
  private var labelKey: String {
    ["music": "label-song", "network": "label-connected", "volume": "label-volume", "disk": "label-mounted"][source] ?? "label"
  }
  private var formatKey: String {
    ["music": "format-online", "network": "format-connected", "volume": "format-volume", "disk": "format-mounted"][source] ?? "format"
  }
  private var choices: [(String, String)] {
    switch source {
    case "cpu": [("Percentage", "%percentage%%"), ("CPU and percentage", "CPU %percentage%%")]
    case "memory": [("Percentage", "%percentage%%"), ("Used memory", "%gb_used% GB"), ("Used / total", "%gb_used% / %gb_total% GB")]
    case "disk": [("Free space", "%free%"), ("Used space", "%used%"), ("Percentage", "%percentage%%")]
    case "volume", "microphone", "brightness", "battery": [("Percentage", "%percentage%%"), ("Value only", "%percentage%")]
    case "network": [("Wi-Fi name", "%essid%"), ("IP address", "%local_ip%"), ("Download / upload", "↓ %downspeed%  ↑ %upspeed%")]
    case "music": [("Track title", "%title%"), ("Artist and title", "%artist% — %title%"), ("Title and time", "%title%  %elapsed% / %total%")]
    case "window": [("Window title", "%title%"), ("App name", "%name%")]
    case "date": [("Time", "%time%"), ("Date", "%date%"), ("Date and time", "%date%  %time%")]
    case "weather": [("Temperature", "%temperature%°"), ("Condition and temperature", "%condition%  %temperature%°")]
    case "temperature": [("Celsius", "%temperature-c%°C"), ("Fahrenheit", "%temperature-f%°F")]
    case "keyboard": [("Short name", "%layout%"), ("Full name", "%name%")]
    case "bluetooth": [("Status", "%power%"), ("Connected devices", "%count% devices")]
    case "command": [("Command output", "%output%")]
    default: []
    }
  }
  var body: some View {
    if !choices.isEmpty || source == "text" {
      SettingsSection(title: "What to show", subtitle: "Choose a ready-made label, or use Advanced for a fully custom layout.", keywords: ["text", "title", "label", "percentage", "icon", "format", "elapsed", "duration"]) {
        if !choices.isEmpty {
          Picker("Label", selection: Binding(get: {
            let current = editor.values[labelKey]?.stringValue ?? ""
            return choices.contains(where: { $0.1 == current }) ? current : "__custom__"
          }, set: { value in
            guard value != "__custom__" else { return }
            setLabel(value)
          })) {
            Text("Current preset layout").tag("__custom__")
            ForEach(choices, id: \.1) { choice in Text(choice.0).tag(choice.1) }
          }.pickerStyle(.menu)
        }
        if source == "text" {
          SettingsTextField(label: "Button text", value: Binding(get: {
            GlanceLabelPart.parse(editor.values["label"]?.stringValue ?? "")
              .filter { $0.kind == .text }.map(\.value).joined().trimmingCharacters(in: .whitespaces)
          }, set: { setLabel($0) }), prompt: "Optional label")
        }
        GlanceSymbolPickerButton(selection: Binding(get: {
          editor.values["native-symbol-label-prefix"]?.stringValue ?? ""
        }, set: { symbol in
          var pairs: [(key: String, value: String)] = [("widgets.\(id).native-symbol-label-prefix", ModuleSettingsEditor.quoted(symbol))]
          if !symbol.isEmpty {
            var layout = editor.values[formatKey]?.stringValue ?? "<\(labelKey)>"
            if let range = layout.range(of: "<ramp-[^>]+>", options: .regularExpression) {
              layout.replaceSubrange(range, with: "<label-prefix>")
            } else if !layout.contains("<label-prefix>") { layout = "<label-prefix> " + layout }
            pairs.append(("widgets.\(id).\(formatKey)", ModuleSettingsEditor.quoted(layout)))
            if source == "text", let label = editor.values[labelKey]?.stringValue,
               label.unicodeScalars.contains(where: { (0xE000...0xF8FF).contains($0.value) }) {
              let clean = label.filter { !$0.unicodeScalars.contains { (0xE000...0xF8FF).contains($0.value) } }
              pairs.append(("widgets.\(id).\(labelKey)", ModuleSettingsEditor.quoted(clean)))
              pairs.append(("widgets.\(id).label-prefix", ModuleSettingsEditor.quoted(label)))
            }
          }
          manager.updateConfigValues(pairs: pairs)
        }), title: "Choose icon")
        if ["music", "network", "window", "weather", "command"].contains(source) {
          Toggle("Limit text length", isOn: Binding(get: { editor.values[labelKey + "-maxlen"] != nil }, set: { enabled in
            if enabled { manager.updateConfigValue(key: "widgets.\(id).\(labelKey)-maxlen", newValue: "30") }
            else { manager.removeConfigValue(key: "widgets.\(id).\(labelKey)-maxlen") }
          }))
          if editor.values[labelKey + "-maxlen"] != nil {
            Stepper("Up to \(editor.values[labelKey + "-maxlen"]?.intValue ?? 30) characters", value: editor.integer(labelKey + "-maxlen", default: 30), in: 5...200)
          }
        }
      }
    }
  }
  private func setLabel(_ value: String) {
    var pairs: [(key: String, value: String)] = [("widgets.\(id).\(labelKey)", ModuleSettingsEditor.quoted(value))]
    if source == "text" {
      var parts = GlanceLabelPart.parse(editor.values[labelKey]?.stringValue ?? "")
      var replaced = false
      for index in parts.indices where parts[index].kind == .text {
        parts[index].value = replaced ? "" : " " + value
        replaced = true
      }
      if !replaced { parts.append(.init(kind: .text, value: " " + value)) }
      manager.updateConfigValue(key: "widgets.\(id).\(labelKey)", newValue: ModuleSettingsEditor.quoted(parts.map(\.serialized).joined()))
      return
    }
    let layout = editor.values[formatKey]?.stringValue ?? ""
    if !layout.contains("<\(labelKey)>") {
      pairs.append(("widgets.\(id).\(formatKey)", ModuleSettingsEditor.quoted("<label-prefix> <\(labelKey)>")))
    }
    manager.updateConfigValues(pairs: pairs)
  }
}
