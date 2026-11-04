import SwiftUI

struct SettingsModule: Identifiable {
  let id: String
  let title: String
  let icon: String
  let summary: String
  var category: String = "Utilities"

  static let categories = ["Desktop", "Media", "System", "Shortcuts", "Utilities", "Layout", "Custom Scripts"]

  static let builtins: [SettingsModule] = [
    .init(
      id: "default.spaces", title: "Spaces", icon: "rectangle.3.group",
      summary: "Workspace indicators, focused spaces, and window titles."),
    .init(
      id: "default.activeapp", title: "Active App", icon: "app.badge",
      summary: "The name of the app in the foreground."),
    .init(
      id: "default.launcher", title: "App Launcher", icon: "square.grid.2x2",
      summary: "Open apps from a compact launcher."),
    .init(
      id: "default.power", title: "Power Menu", icon: "power", summary: "Session and power actions."
    ),
    .init(
      id: "default.nowplaying", title: "Now Playing", icon: "music.note",
      summary: "Track information, playback time, and the music visualizer."),
    .init(
      id: "default.mediacontrols", title: "Media Controls", icon: "playpause",
      summary: "Previous track, play or pause, and next track."),
    .init(
      id: "default.volume", title: "Volume", icon: "speaker.wave.2",
      summary: "System volume and mouse wheel adjustments."),
    .init(
      id: "default.network", title: "Network", icon: "wifi",
      summary: "Wi-Fi, Ethernet, or your local IP address."),
    .init(
      id: "default.weather", title: "Weather", icon: "cloud.sun",
      summary: "Weather provider and location."),
    .init(
      id: "default.systemmonitor", title: "System Monitor", icon: "gauge.medium",
      summary: "CPU and memory usage."),
    .init(
      id: "default.temperature", title: "Temperature", icon: "thermometer",
      summary: "Hardware temperature."),
    .init(id: "default.fan", title: "Fan Speed", icon: "fan", summary: "Hardware fan speed."),
    .init(
      id: "default.energy", title: "Energy", icon: "bolt", summary: "System power consumption."),
    .init(
      id: "default.disk", title: "Disk", icon: "internaldrive",
      summary: "Available disk space and storage details."),
    .init(
      id: "default.pomodoro", title: "Pomodoro", icon: "timer",
      summary: "Focus sessions and break durations."),
    .init(
      id: "default.inputlanguage", title: "Input Language", icon: "keyboard",
      summary: "Current keyboard input source."),
    .init(
      id: "default.brightness", title: "Brightness", icon: "sun.max",
      summary: "Display brightness and mouse wheel adjustments."),
    .init(
      id: "default.clipboard", title: "Clipboard", icon: "doc.on.clipboard",
      summary: "Recent clipboard entries."),
    .init(
      id: "default.bluetooth", title: "Bluetooth", icon: "wave.3.right",
      summary: "Bluetooth connection status and device details."),
    .init(
      id: "default.battery", title: "Battery", icon: "battery.75percent",
      summary: "Charge level and low battery thresholds."),
    .init(
      id: "default.time", title: "Time & Calendar", icon: "clock",
      summary: "Date formatting, the clock, and upcoming events."),
  ]

  static func all(config: Config) -> [SettingsModule] {
    var scriptIDs = Set(
      (config.rootToml.widgets?.displayed ?? []).map(\.id).filter { $0.hasPrefix("script.") })
    for (section, values) in config.rootToml.widgets?.others ?? [:] {
      if section == "script" {
        for (name, value) in values where value.dictionaryValue != nil {
          scriptIDs.insert("script.\(name)")
        }
      } else if section.hasPrefix("script.") {
        scriptIDs.insert(section)
      }
    }
    let active = Set((config.rootToml.widgets?.displayed ?? []).map(\.id))
    let nativeSources = Set(scriptIDs.filter { active.contains($0) }.compactMap {
      config.rootToml.widgets?.config(for: $0)?["native-source"]?.stringValue
    })
    let nativeActions = Set(scriptIDs.filter { active.contains($0) }.compactMap {
      config.rootToml.widgets?.config(for: $0)?["native-action"]?.stringValue
    })
    let equivalentActions = ["default.launcher": "launcher", "default.power": "power"]
    let equivalent = ["default.spaces": "workspaces", "default.activeapp": "window", "default.nowplaying": "music", "default.volume": "volume", "default.network": "network", "default.brightness": "brightness", "default.time": "date", "default.disk": "disk", "default.weather": "weather", "default.temperature": "temperature", "default.inputlanguage": "keyboard"]
    return builtins.filter { module in
      let hasProvider = equivalent[module.id].map { nativeSources.contains($0) } ?? false
      let hasAction = equivalentActions[module.id].map { nativeActions.contains($0) } ?? false
      return active.contains(module.id) || (!hasProvider && !hasAction)
    }.map { descriptor(for: $0.id, config: config) }
      + scriptIDs.sorted().map { descriptor(for: $0, config: config) }
  }

  static func descriptor(for id: String, config: Config? = nil) -> SettingsModule {
    if let values = config?.rootToml.widgets?.config(for: id),
       let source = values["native-source"]?.stringValue {
      let providers: [String: (String, String, String)] = [
        "cpu": ("CPU", "cpu", "System"), "memory": ("Memory", "memorychip", "System"),
        "user": ("User Badge", "person.crop.circle", "Desktop"),
        "microphone": ("Microphone Gain", "mic", "Media"), "updates": ("Glance Updates", "arrow.triangle.2.circlepath", "System"),
        "disk": ("Storage", "internaldrive", "System"), "volume": ("Volume", "speaker.wave.2", "Media"),
        "bluetooth": ("Bluetooth", "wave.3.right", "System"), "brightness": ("Brightness", "sun.max", "System"), "network": ("Network", "wifi", "System"),
        "weather": ("Weather", "cloud.sun", "System"), "visualizer": ("Music Visualizer", "waveform", "Media"),
        "music": ("Now Playing", "music.note", "Media"), "workspaces": ("Spaces", "rectangle.3.group", "Desktop"),
        "window": ("Window Title", "macwindow", "Desktop"), "date": ("Clock", "clock", "Desktop"),
        "temperature": ("Temperature", "thermometer", "System"), "keyboard": ("Input Language", "keyboard", "Desktop")
      ]
      if let info = providers[source] {
        return .init(id: id, title: values["module-name"]?.stringValue ?? info.0, icon: info.1,
                     summary: "Live macOS data with customizable text, icons, colors, and actions.", category: info.2)
      }
      if GlanceTransitionWidget.isDecoration(values) {
        let name = id.split(separator: ".").last.map(String.init) ?? ""
        let number = name.filter(\.isNumber)
        return .init(id: id, title: name.contains("sep") ? "Separator" : (name.contains("left") ? "Left Transition" : name.contains("right") ? "Right Transition" : "Color Transition") + (number.isEmpty ? "" : " " + number),
                     icon: "square.leadinghalf.filled", summary: "Connect neighboring module backgrounds or add a separator.", category: "Layout")
      }
      let action = values["native-action"]?.stringValue ?? ""
      let actions: [String: (String, String)] = [
        "shuffle-colors": ("Palette Shuffle", "paintpalette"), "style": ("Palette", "paintpalette"),
        "launcher": ("App Launcher", "square.grid.2x2"), "power": ("Power Menu", "power"),
        "settings": ("Settings", "gearshape"), "terminal": ("Terminal", "terminal"),
        "open-app": ("App Shortcut", "app"), "files": ("Files", "folder"), "browser": ("Browser", "globe"), "updates": ("Software Updates", "arrow.down.circle")
      ]
      let name = id.replacingOccurrences(of: "script.adi_", with: "").replacingOccurrences(of: "script.", with: "").replacingOccurrences(of: "_", with: " ").capitalized
      let info = actions[action] ?? (name, action.hasPrefix("https://") ? "link" : "textformat")
      return .init(id: id, title: values["module-name"]?.stringValue ?? info.0, icon: info.1,
                   summary: action == "shuffle-colors" ? "Shuffle widget colors for this session. Saved themes stay unchanged." : "A customizable shortcut with its own icon, label, and colors.",
                   category: action == "updates" ? "System" : "Shortcuts")
    }
    if var module = builtins.first(where: { $0.id == id }) {
      switch id {
      case "default.spaces", "default.activeapp", "default.time", "default.inputlanguage": module.category = "Desktop"
      case "default.nowplaying", "default.mediacontrols", "default.volume": module.category = "Media"
      case "default.systemmonitor", "default.temperature", "default.fan", "default.energy", "default.disk", "default.brightness", "default.network", "default.battery", "default.weather": module.category = "System"
      case "default.launcher", "default.power": module.category = "Shortcuts"
      default: module.category = "Utilities"
      }
      return module
    }
    return .init(id: id, title: id.replacingOccurrences(of: "script.", with: "").replacingOccurrences(of: "_", with: " ").capitalized,
                 icon: "terminal", summary: "Command output, formatting, and click actions.", category: "Custom Scripts")
  }
}
