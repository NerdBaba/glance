import SwiftUI

struct TimeSettingsTab: View {
  @ObservedObject var configManager = ConfigManager.shared

  @State private var dateFormat: String = "E d, H:mm"
  @State private var calendarFormat: String = "H:mm"
  @State private var showEvents: Bool = true
  @State private var currentTime = Date()
  @State private var showIcon = false
  @State private var iconGlyph = ""
  @State private var contentSpacing = 8.0

  private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

  private let formatPresets: [(label: String, pattern: String)] = [
    ("Weekday + time (24-hour)", "E d, H:mm"),
    ("Date + time", "E d MMM, H:mm"),
    ("Time (24-hour)", "H:mm"),
    ("Time (12-hour)", "h:mm a"),
    ("Numeric date + time", "d.MM.yyyy H:mm"),
    ("Full weekday + date", "EEEE, d MMMM"),
  ]

  @State private var synchronizedValues: [String: String] = [:]

  var body: some View {
    SettingsPage(moduleID: "default.time") {
      SettingsSection(title: "Date Format", keywords: ["%.0f", "Date format", "Format", "Icon spacing", "Presets", "Preview", "Show clock icon", "checkmark", "false", "showIcon", "true"]) {
        Toggle("Show clock icon", isOn: $showIcon)
          .onChange(of: showIcon) { _, value in
            guard String(describing: value) != synchronizedValues["showIcon"] else { return }
            configManager.updateConfigValue(
              key: "widgets.default.time.show-icon", newValue: value ? "true" : "false")
          }
        if showIcon {
          SliderRow(
            label: "Icon spacing", value: $contentSpacing, range: 0...32, step: 1, format: "%.0f"
          ) {
            configManager.updateConfigValue(
              key: "widgets.default.time.content-spacing", newValue: String(contentSpacing))
          }
        }
        Picker("Clock style", selection: Binding(get: {
          formatPresets.contains(where: { $0.pattern == dateFormat }) ? dateFormat : "__custom__"
        }, set: { pattern in
          guard pattern != "__custom__" else { return }
          dateFormat = pattern
          configManager.updateConfigValue(key: "widgets.default.time.format", newValue: pattern)
        })) {
          Text("Current custom format").tag("__custom__")
          ForEach(formatPresets, id: \.pattern) { preset in
            Text(preset.label + " · " + formattedTime(pattern: preset.pattern)).tag(preset.pattern)
          }
        }.pickerStyle(.menu)
      }
      SettingsSection(title: "Custom date formats", area: .advanced, keywords: ["date", "time", "pattern", "format", "calendar"]) {
        SettingsTextField(label: "Clock pattern", value: ModuleSettingsEditor(id: "default.time").string("format", default: "E d, H:mm"))
        LabeledContent("Example", value: formattedTime(pattern: dateFormat))
        SettingsTextField(label: "Calendar event pattern", value: Binding(get: {
          configManager.globalWidgetConfig(for: "default.time")["calendar"]?.dictionaryValue?["format"]?.stringValue ?? "H:mm"
        }, set: { configManager.updateConfigValue(key: "widgets.default.time.calendar.format", newValue: $0) }))
      }

      SettingsSection(title: "Calendar", area: .behavior, keywords: ["Calendar format", "Event time format", "Show next event", "false", "showEvents", "true"]) {
        Toggle("Show next event", isOn: $showEvents)
          .onChange(of: showEvents) { _, newValue in
            guard String(describing: newValue) != synchronizedValues["showEvents"] else { return }
            configManager.updateConfigValue(
              key: "widgets.default.time.calendar.show-events",
              newValue: newValue ? "true" : "false")
          }

      }

      ModuleIconSettings(id: "default.time")
      ModuleAppearanceSettings(id: "default.time")
    }
    .onAppear { syncFromConfig() }
    .onChange(of: configManager.config.updatedAt) { _, _ in syncFromConfig() }
    .onReceive(timer) { date in currentTime = date }
  }

  private func syncFromConfig() {
    let timeConfig = configManager.globalWidgetConfig(for: "default.time")
    dateFormat = timeConfig["format"]?.stringValue ?? "E d, H:mm"
    showIcon = timeConfig["show-icon"]?.boolValue ?? false
    iconGlyph = timeConfig["glyph"]?.stringValue ?? ""
    contentSpacing = timeConfig["content-spacing"]?.doubleValue ?? 8
    let calConfig = timeConfig["calendar"]?.dictionaryValue ?? [:]
    calendarFormat = calConfig["format"]?.stringValue ?? "H:mm"
    showEvents = calConfig["show-events"]?.boolValue ?? true
    synchronizedValues = [
      "dateFormat": String(describing: dateFormat),
      "calendarFormat": String(describing: calendarFormat),
      "showEvents": String(describing: showEvents),
      "showIcon": String(describing: showIcon),
      "iconGlyph": String(describing: iconGlyph),
      "contentSpacing": String(describing: contentSpacing),
    ]
  }

  private func formattedTime(pattern: String) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = pattern
    formatter.timeZone = .current
    return formatter.string(from: currentTime)
  }
}
