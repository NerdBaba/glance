import SwiftUI

struct MusicPlaybackSettings: View {
  let id: String
  private var editor: ModuleSettingsEditor { .init(id: id) }

  var body: some View {
    SettingsSection(title: "Playback time & progress", keywords: ["%.2f", "Show elapsed time", "Show progress bar", "Show track duration", "Time separator", "Time text opacity", "Track / time spacing", "Track padding", "content-padding", "content-spacing", "show-duration", "show-position", "show-progress", "time-opacity", "time-separator"]) {
      Toggle("Show elapsed time", isOn: editor.bool("show-position"))
      Toggle("Show track duration", isOn: editor.bool("show-duration"))
      Toggle("Show progress bar", isOn: editor.bool("show-progress"))
      SettingsTextField(
        label: "Time separator", value: editor.string("time-separator", default: " / "))
      ModuleSlider(
        label: "Time text opacity", value: editor.number("time-opacity", default: 0.72),
        range: 0...1, step: 0.01, format: "%.2f")
      ModuleSlider(
        label: "Track / time spacing", value: editor.number("content-spacing", default: 5),
        range: 0...48)
      ModuleSlider(
        label: "Track padding", value: editor.number("content-padding", default: 4), range: 0...24)
    }
  }
}

struct AdditionalModuleSettings: View {
  let id: String
  private var editor: ModuleSettingsEditor { .init(id: id) }

  @ViewBuilder var body: some View {
    switch id {
    case "default.pomodoro":
      SettingsSection(title: "Sessions & breaks", keywords: ["break-duration", "long-break-duration", "sessions-before-long-break", "work-duration"]) {
        Stepper(
          "Focus: \(editor.integer("work-duration", default: 25).wrappedValue) minutes",
          value: editor.integer("work-duration", default: 25), in: 1...180)
        Stepper(
          "Short break: \(editor.integer("break-duration", default: 5).wrappedValue) minutes",
          value: editor.integer("break-duration", default: 5), in: 1...60)
        Stepper(
          "Long break: \(editor.integer("long-break-duration", default: 15).wrappedValue) minutes",
          value: editor.integer("long-break-duration", default: 15), in: 1...120)
        Stepper(
          "Sessions before long break: \(editor.integer("sessions-before-long-break", default: 4).wrappedValue)",
          value: editor.integer("sessions-before-long-break", default: 4), in: 1...12)
      }
    case "default.clipboard":
      SettingsSection(title: "History", keywords: ["Clipboard history is kept in memory for this session.", "max-entries"]) {
        Stepper(
          "Keep \(editor.integer("max-entries", default: 20).wrappedValue) entries",
          value: editor.integer("max-entries", default: 20), in: 1...100)
        Text("Clipboard history is kept in memory for this session.").foregroundStyle(.secondary)
      }
    case "default.activeapp", "default.disk", "default.inputlanguage":
      SettingsSection(title: "Content") {
        Text(contentDescription).foregroundStyle(.secondary).fixedSize(
          horizontal: false, vertical: true)
      }
    default:
      if id.hasPrefix("script.") { ScriptModuleSettings(id: id) }
    }
  }

  private var contentDescription: String {
    switch id {
    case "default.activeapp":
      return "Shows the name of the focused app. Customize its text and segment below."
    case "default.disk":
      return
        "Shows free space on the startup disk. Click the module in the bar to see storage details."
    default:
      return
        "Shows the current input language. Click the module in the bar to choose an input source."
    }
  }
}

struct ScriptModuleSettings: View {
  let id: String
  private var editor: ModuleSettingsEditor { .init(id: id) }

  var body: some View {
    if GlanceTransitionWidget.isDecoration(editor.values) {
      GlanceTransitionSettings(id: id)
    } else {
    if !["user", "visualizer", "music-artwork"].contains(editor.values["native-source"]?.stringValue ?? "") {
      GlanceQuickContentSettings(id: id)
      GlanceSimpleLabelEditor(id: id)
    }
    if let source = editor.values["native-source"]?.stringValue {
      SettingsSection(title: "Module identity", subtitle: "Rename the widget or change the kind of data it shows.", area: .advanced, keywords: ["Album cover", "Automatic", "Battery", "Bluetooth", "Brightness", "CPU", "Data source", "Date & time", "Focused window", "Glance updates", "Keyboard layout", "Memory", "Microphone", "Module name", "Music", "Network", "Playback animation", "Spaces", "Storage", "Temperature", "Text / shortcut", "User picture", "Volume", "Weather", "battery", "bluetooth", "brightness", "cpu", "date", "disk", "keyboard", "memory", "microphone", "module-name", "music", "music-artwork", "native-source", "network", "temperature", "text", "updates", "user", "visualizer", "volume", "weather", "window", "workspaces"]) {
        SettingsTextField(label: "Module name", value: editor.string("module-name", removeEmpty: true), prompt: "Automatic")
        Picker("Data source", selection: editor.string("native-source", default: "text")) {
          ForEach([("text", "Text / shortcut"), ("cpu", "CPU"), ("memory", "Memory"), ("disk", "Storage"), ("volume", "Volume"), ("microphone", "Microphone"), ("brightness", "Brightness"), ("battery", "Battery"), ("network", "Network"), ("bluetooth", "Bluetooth"), ("music", "Music"), ("music-artwork", "Album cover"), ("date", "Date & time"), ("workspaces", "Spaces"), ("window", "Focused window"), ("keyboard", "Keyboard layout"), ("weather", "Weather"), ("temperature", "Temperature"), ("visualizer", "Playback animation"), ("updates", "Glance updates"), ("user", "User picture")], id: \.0) { choice in
            Text(choice.1).tag(choice.0)
          }
        }
      }
      if ["workspaces", "user", "music-artwork", "date", "visualizer", "weather"].contains(source) {
      SettingsSection(title: "Display options", keywords: [", with: ", "All spaces", "Avatar size", "Bar thickness", "Bars", "Baseline", "Bottom", "Bottom color", "Centered", "Clock row spacing", "Cover corner radius", "Cover size", "Date layout", "Date pattern", "EEE MMM d", "Fallback avatar icon", "Focused space only", "Formatted label", "HH:mm", "Height", "Line spacing", "Playback animation follows play/pause state; it is not an audio spectrum measurement.", "Refresh every second", "Spaces to display", "Stacked time and date", "System time zone", "Text lines", "Time pattern", "Time zone", "Top color", "Use login picture", "Uses the current track's artwork when the player supplies it. Clicking toggles playback.", "Vertical rail clock", "Width", "all", "bottom", "center", "date", "date-font", "date-layout", "date-pattern", "date-stack-spacing", "focused-only", "formatted", "music-artwork", "music-artwork-radius", "music-artwork-size", "native-display-mode", "native-line-limit", "native-symbol-label-prefix", "rail", "rail-clock-spacing", "rail-date-font", "rail-period-font", "rail-time-font", "rail-weekday-font", "seconds", "stacked", "time-pattern", "time-zone", "user", "user-avatar-size", "user-show-photo", "visualizer", "visualizer-bar-width", "visualizer-baseline", "visualizer-color", "visualizer-color-2", "visualizer-count", "visualizer-height", "visualizer-width", "weather", "workspaces"]) {
        if source == "workspaces" {
          Picker("Spaces to display", selection: editor.string("native-display-mode", default: "all")) {
            Text("All spaces").tag("all")
            Text("Focused space only").tag("focused-only")
          }
        }
        if source == "user" {
          GlanceSymbolPickerButton(selection: editor.string("native-symbol-label-prefix", removeEmpty: true), title: "Fallback avatar icon")
          Toggle("Use login picture", isOn: editor.bool("user-show-photo", default: true))
          ModuleSlider(label: "Avatar size", value: editor.number("user-avatar-size", default: 24), range: 16...40)
        }
        if source == "music-artwork" {
          ModuleSlider(label: "Cover size", value: editor.number("music-artwork-size", default: 20), range: 12...80)
          ModuleSlider(label: "Cover corner radius", value: editor.number("music-artwork-radius", default: 3), range: 0...40)
          Text("Uses the current track's artwork when the player supplies it. Clicking toggles playback.").foregroundStyle(.secondary)
        }
        if source == "date" {
          Picker("Date layout", selection: editor.string("date-layout", default: "formatted")) {
            Text("Formatted label").tag("formatted")
            Text("Stacked time and date").tag("stacked")
            Text("Vertical rail clock").tag("rail")
          }
          if editor.values["date-layout"]?.stringValue == "stacked" {
            GlanceComponentFontControl(id: id, key: "date-font")
            ModuleSlider(label: "Line spacing", value: editor.number("date-stack-spacing", default: 0), range: 0...20)
          }
          if editor.values["date-layout"]?.stringValue == "rail" {
            ForEach(["rail-weekday-font", "rail-date-font", "rail-time-font", "rail-period-font"], id: \.self) { key in
              GlanceComponentFontControl(id: id, key: key)
            }
            ModuleSlider(label: "Clock row spacing", value: editor.number("rail-clock-spacing", default: 3), range: 0...12)
          }
          GlanceDatePatternField(id: id, key: "date-pattern", title: "Date pattern", fallback: "EEE MMM d")
          GlanceDatePatternField(id: id, key: "time-pattern", title: "Time pattern", fallback: "HH:mm")
          Picker("Time zone", selection: editor.string("time-zone", default: "")) {
            Text("System time zone").tag("")
            ForEach(TimeZone.knownTimeZoneIdentifiers, id: \.self) { zone in Text(zone.replacingOccurrences(of: "_", with: " ")).tag(zone) }
          }
          Toggle("Refresh every second", isOn: editor.bool("seconds"))
          ModuleSlider(label: "Text lines", value: editor.number("native-line-limit", default: 1), range: 1...8)
        }
        if source == "visualizer" {
          Text("Playback animation follows play/pause state; it is not an audio spectrum measurement.").foregroundStyle(.secondary)
          ModuleSlider(label: "Bars", value: editor.number("visualizer-count", default: 40), range: 3...100)
          ModuleSlider(label: "Width", value: editor.number("visualizer-width", default: 200), range: 30...600)
          ModuleSlider(label: "Height", value: editor.number("visualizer-height", default: 18), range: 4...80)
          ModuleSlider(label: "Bar thickness", value: editor.number("visualizer-bar-width", default: 3), range: 1...20)
          Picker("Baseline", selection: editor.string("visualizer-baseline", default: "bottom")) {
            Text("Bottom").tag("bottom")
            Text("Centered").tag("center")
          }
          ModuleColorControl(label: "Bottom color", value: editor.string("visualizer-color", removeEmpty: true))
          ModuleColorControl(label: "Top color", value: editor.string("visualizer-color-2", removeEmpty: true))
        }
        if source == "weather" { WeatherModuleSettings(id: id) }

      }
      }
      if source == "workspaces" {
        SettingsSection(title: "Space indicators", area: .appearance, keywords: ["Active label minimum width", "Active pill width", "Configured labels", "Direction", "Dot click height", "Dot click width", "Dot size", "Dot spacing", "Dots with active pill", "Filled dots", "Filled dots with active ring", "Horizontal", "Inactive dot opacity", "Indicator shape", "Label background height", "Label background radius", "Label minimum width", "Label spacing", "Outlined rings", "Space ", "Vertical", "dot", "horizontal", "label", "native-orientation", "pill", "ring", "ring-active", "vertical", "workspace-active-width", "workspace-color-", "workspace-dot-size", "workspace-dot-spacing", "workspace-hit-height", "workspace-hit-width", "workspace-inactive-opacity", "workspace-indicator", "workspace-label-active-width", "workspace-label-height", "workspace-label-radius", "workspace-label-spacing", "workspace-label-width"]) {
        Group {
          Picker("Direction", selection: editor.string("native-orientation", default: "horizontal")) {
            Text("Horizontal").tag("horizontal")
            Text("Vertical").tag("vertical")
          }
          Picker("Indicator shape", selection: editor.string("workspace-indicator", default: "label")) {
            Text("Configured labels").tag("label")
            Text("Filled dots").tag("dot")
            Text("Outlined rings").tag("ring")
            Text("Filled dots with active ring").tag("ring-active")
            Text("Dots with active pill").tag("pill")
          }
          if editor.values["workspace-indicator"]?.stringValue != nil && editor.values["workspace-indicator"]?.stringValue != "label" {
            ModuleSlider(label: "Dot size", value: editor.number("workspace-dot-size", default: 12), range: 4...32)
            ModuleSlider(label: "Dot spacing", value: editor.number("workspace-dot-spacing", default: 4), range: 0...32)
            ModuleSlider(label: "Inactive dot opacity", value: editor.number("workspace-inactive-opacity", default: 1), range: 0...1)
            ModuleSlider(label: "Dot click width", value: editor.number("workspace-hit-width", default: 16), range: 4...48)
            ModuleSlider(label: "Dot click height", value: editor.number("workspace-hit-height", default: 24), range: 4...48)
            ModuleSlider(label: "Active pill width", value: editor.number("workspace-active-width", default: 26), range: 12...80)
          } else {
            ModuleSlider(label: "Label background radius", value: editor.number("workspace-label-radius", default: 0), range: 0...40)
            ModuleSlider(label: "Label background height", value: editor.number("workspace-label-height", default: 26), range: 8...80)
            ModuleSlider(label: "Label minimum width", value: editor.number("workspace-label-width", default: 0), range: 0...80)
            ModuleSlider(label: "Active label minimum width", value: editor.number("workspace-label-active-width", default: 0), range: 0...80)
            ModuleSlider(label: "Label spacing", value: editor.number("workspace-label-spacing", default: 0), range: 0...32)
          }
          ForEach(editor.values.keys.filter { $0.hasPrefix("workspace-color-") }.sorted(), id: \.self) { key in
            ModuleColorControl(label: "Space " + key.replacingOccurrences(of: "workspace-color-", with: ""), value: editor.string(key, removeEmpty: true))
          }
        }
        }
      }
      SettingsSection(title: "Icon & orientation", area: .appearance, keywords: ["Downwards", "Horizontal", "Icon size", "Text direction", "Upwards", "down", "horizontal", "native-icon-size", "native-text-direction", "up", "user", "visualizer", "workspaces"]) {
        ModuleSlider(label: "Icon size", value: editor.number("native-icon-size", default: 14), range: 8...40)
        if !["user", "visualizer", "workspaces"].contains(source) {
          Picker("Text direction", selection: editor.string("native-text-direction", default: "horizontal")) {
            Text("Horizontal").tag("horizontal")
            Text("Downwards").tag("down")
            Text("Upwards").tag("up")
          }
        }
      }
    } else {
    SettingsSection(
      title: "Command & refresh", subtitle: "Press Return or leave a text field to apply it."
    , keywords: ["%.0f seconds", "Command", "Command timeout", "Optional condition command", "Read continuous output (tail)", "Refresh interval", "Run only if", "Shell command", "command", "exec", "exec-if", "interval", "tail", "timeout"]) {
      SettingsTextField(
        label: "Command",
        value: editor.string(
          editor.values["exec"] == nil && editor.values["command"] != nil ? "command" : "exec"),
        prompt: "Shell command")
      Toggle("Read continuous output (tail)", isOn: editor.bool("tail"))
      ModuleSlider(
        label: "Refresh interval", value: editor.number("interval", default: 5), range: 0...300,
        format: "%.0f seconds")
      ModuleSlider(
        label: "Command timeout", value: editor.number("timeout", default: 5), range: 1...120,
        format: "%.0f seconds")
      SettingsTextField(
        label: "Run only if", value: editor.string("exec-if", removeEmpty: true),
        prompt: "Optional condition command")
    }
    }
    if editor.values["native-source"]?.stringValue == "music" { GlanceMusicDetailsSettings(id: id) }
    GlanceModulePreviewSettings(id: id)
    GlanceActionSettings(id: id)
    if !["user", "visualizer"].contains(editor.values["native-source"]?.stringValue ?? "") {
      GlanceFormattingSettings(id: id)
    }
    SettingsSection(title: "Shared capsule", subtitle: "Consecutive modules with the same group name share one background. Style is set on the first module in the group.", area: .advanced, keywords: ["Background", "Background opacity", "Centered", "Content alignment", "Corner radius", "Group name", "Height", "Horizontal padding", "Minimum width", "Module spacing", "None", "Right aligned", "Vertical padding", "Vertical rail group width", "capsule-alignment", "capsule-background", "capsule-background-opacity", "capsule-group", "capsule-height", "capsule-min-width", "capsule-padding", "capsule-radius", "capsule-spacing", "capsule-vertical-padding", "capsule-width", "center", "right"]) {
      SettingsTextField(label: "Group name", value: editor.string("capsule-group", removeEmpty: true), prompt: "None")
      if editor.values["capsule-group"]?.stringValue?.isEmpty == false {
        ModuleColorControl(label: "Background", value: editor.string("capsule-background", removeEmpty: true))
        ModuleSlider(label: "Background opacity", value: editor.number("capsule-background-opacity", default: 1), range: 0...1)
        ModuleSlider(label: "Height", value: editor.number("capsule-height", default: 28), range: 20...100)
        ModuleSlider(label: "Corner radius", value: editor.number("capsule-radius", default: 14), range: 0...50)
        ModuleSlider(label: "Minimum width", value: editor.number("capsule-min-width", default: 0), range: 0...1200)
        Picker("Content alignment", selection: editor.string("capsule-alignment", default: "center")) {
          Text("Centered").tag("center")
          Text("Right aligned").tag("right")
        }
        ModuleSlider(label: "Horizontal padding", value: editor.number("capsule-padding", default: 4), range: 0...40)
        ModuleSlider(label: "Vertical rail group width", value: editor.number("capsule-width", default: 34), range: 20...160)
        ModuleSlider(label: "Vertical padding", value: editor.number("capsule-vertical-padding", default: 8), range: 0...40)
        ModuleSlider(label: "Module spacing", value: editor.number("capsule-spacing", default: 0), range: 0...40)
      }
    }
    }
  }
}
