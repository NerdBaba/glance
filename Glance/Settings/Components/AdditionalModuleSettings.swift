import SwiftUI

struct MusicPlaybackSettings: View {
  let id: String
  private var editor: ModuleSettingsEditor { .init(id: id) }

  var body: some View {
    SettingsSection(title: "Playback time & progress") {
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
      SettingsSection(title: "Sessions & breaks") {
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
      SettingsSection(title: "History") {
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
    SettingsSection(
      title: "Command & refresh", subtitle: "Press Return or leave a text field to apply it."
    ) {
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
    SettingsSection(title: "Output formatting") {
      SettingsTextField(label: "Format", value: editor.string("format", default: "<label>"))
      SettingsTextField(label: "Label", value: editor.string("label", default: "%output%"))
      SettingsTextField(label: "Prefix", value: editor.string("format-prefix", removeEmpty: true))
      SettingsTextField(label: "Suffix", value: editor.string("format-suffix", removeEmpty: true))
      SettingsTextField(
        label: "Failure format", value: editor.string("format-fail", removeEmpty: true))
      Text(
        "Use Polybar labels, ramps, progress bars, and formatting tags. Additional options remain available in your TOML config."
      )
      .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
    }
    SettingsSection(title: "Click & scroll actions") {
      SettingsTextField(label: "Left click", value: editor.string("click-left", removeEmpty: true))
      SettingsTextField(
        label: "Middle click", value: editor.string("click-middle", removeEmpty: true))
      SettingsTextField(
        label: "Right click", value: editor.string("click-right", removeEmpty: true))
      SettingsTextField(label: "Scroll up", value: editor.string("scroll-up", removeEmpty: true))
      SettingsTextField(
        label: "Scroll down", value: editor.string("scroll-down", removeEmpty: true))
      DisclosureGroup("Double click actions") {
        VStack(alignment: .leading, spacing: 16) {
          SettingsTextField(
            label: "Left double click", value: editor.string("double-click-left", removeEmpty: true)
          )
          SettingsTextField(
            label: "Middle double click",
            value: editor.string("double-click-middle", removeEmpty: true))
          SettingsTextField(
            label: "Right double click",
            value: editor.string("double-click-right", removeEmpty: true))
        }.padding(.top, 12)
      }
    }
  }
}
