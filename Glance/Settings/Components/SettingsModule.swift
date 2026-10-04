import SwiftUI

struct SettingsModule: Identifiable {
  let id: String
  let title: String
  let icon: String
  let summary: String

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
    return builtins + scriptIDs.sorted().map { descriptor(for: $0) }
  }

  static func descriptor(for id: String) -> SettingsModule {
    builtins.first { $0.id == id }
      ?? .init(
        id: id, title: "Script · \(id.replacingOccurrences(of: "script.", with: ""))",
        icon: "terminal", summary: "Command output, formatting, and click actions."
      )
  }
}
