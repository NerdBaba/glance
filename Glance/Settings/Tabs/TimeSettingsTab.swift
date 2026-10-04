import SwiftUI

struct TimeSettingsTab: View {
  @ObservedObject var configManager = ConfigManager.shared

  @State private var dateFormat: String = "E d, J:mm"
  @State private var calendarFormat: String = "J:mm"
  @State private var showEvents: Bool = true
  @State private var currentTime = Date()
  @State private var showIcon = false
  @State private var iconGlyph = ""
  @State private var contentSpacing = 8.0

  private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

  private let formatPresets: [(label: String, pattern: String)] = [
    ("E d, H:mm", "E d, H:mm"),
    ("E d MMM, H:mm", "E d MMM, H:mm"),
    ("H:mm", "H:mm"),
    ("h:mm a", "h:mm a"),
    ("d.MM.yyyy H:mm", "d.MM.yyyy H:mm"),
    ("EEEE, d MMMM", "EEEE, d MMMM"),
  ]

  @State private var synchronizedValues: [String: String] = [:]

  var body: some View {
    SettingsPage {
      ModuleSettingsHeader(id: "default.time")
      SettingsSection(title: "Date Format") {
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
        HStack {
          Text("Format")
            .frame(width: 130, alignment: .leading)
          TextField("Date format", text: $dateFormat)
            .textFieldStyle(.roundedBorder)
            .onSubmit {
              configManager.updateConfigValue(
                key: "widgets.default.time.format",
                newValue: dateFormat)
            }
        }

        HStack {
          Text("Preview")
            .frame(width: 130, alignment: .leading)
            .foregroundStyle(.secondary)
          Text(formattedTime(pattern: dateFormat))
            .font(.system(.body, design: .monospaced))
        }

        Divider()

        Text("Presets")
          .font(.subheadline)
          .foregroundStyle(.secondary)

        ForEach(formatPresets, id: \.pattern) { preset in
          HStack {
            Button(action: {
              dateFormat = preset.pattern
              configManager.updateConfigValue(
                key: "widgets.default.time.format",
                newValue: preset.pattern)
            }) {
              HStack {
                Text(preset.label)
                  .font(.system(.body, design: .monospaced))
                  .frame(width: 180, alignment: .leading)
                Text(formattedTime(pattern: preset.pattern))
                  .foregroundStyle(.secondary)
              }
            }
            .buttonStyle(.plain)
            Spacer()
            if dateFormat == preset.pattern {
              Image(systemName: "checkmark")
                .foregroundStyle(.blue)
            }
          }
        }
      }

      SettingsSection(title: "Calendar") {
        Toggle("Show next event", isOn: $showEvents)
          .onChange(of: showEvents) { _, newValue in
            guard String(describing: newValue) != synchronizedValues["showEvents"] else { return }
            configManager.updateConfigValue(
              key: "widgets.default.time.calendar.show-events",
              newValue: newValue ? "true" : "false")
          }

        HStack {
          Text("Event time format")
            .frame(width: 130, alignment: .leading)
          TextField("Calendar format", text: $calendarFormat)
            .textFieldStyle(.roundedBorder)
            .onSubmit {
              configManager.updateConfigValue(
                key: "widgets.default.time.calendar.format",
                newValue: calendarFormat)
            }
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
    dateFormat = timeConfig["format"]?.stringValue ?? "E d, J:mm"
    showIcon = timeConfig["show-icon"]?.boolValue ?? false
    iconGlyph = timeConfig["glyph"]?.stringValue ?? ""
    contentSpacing = timeConfig["content-spacing"]?.doubleValue ?? 8
    let calConfig = timeConfig["calendar"]?.dictionaryValue ?? [:]
    calendarFormat = calConfig["format"]?.stringValue ?? "J:mm"
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
