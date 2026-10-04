import SwiftUI

enum SettingsDestination: Hashable {
  case appearance, layout, widgets, fonts
  case module(String)
  case randomazzo, application, about
}

struct SettingsView: View {
  @ObservedObject private var configManager = ConfigManager.shared
  @State private var selection: SettingsDestination? = .appearance
  @State private var search = ""

  private var modules: [SettingsModule] {
    SettingsModule.all(config: configManager.config).filter {
      search.isEmpty || $0.title.localizedCaseInsensitiveContains(search)
        || $0.id.localizedCaseInsensitiveContains(search)
    }
  }

  var body: some View {
    NavigationSplitView {
      List(selection: $selection) {
        if search.isEmpty {
          Section("Bar") {
            route("Appearance", icon: "paintpalette", to: .appearance)
            route("Layout", icon: "rectangle.3.group", to: .layout)
            route("Widget order", icon: "list.bullet", to: .widgets)
            route("Fonts", icon: "textformat", to: .fonts)
          }
        }
        Section("Modules") {
          ForEach(modules) { module in
            HStack(spacing: 10) {
              Label(module.title, systemImage: module.icon)
              Spacer(minLength: 0)
              if configManager.config.rootToml.widgets?.displayed.contains(where: {
                $0.id == module.id
              }) == true {
                Circle().fill(Color.accentColor).frame(width: 5, height: 5)
                  .accessibilityLabel("In bar")
              }
            }
            .tag(SettingsDestination.module(module.id))
          }
          if modules.isEmpty {
            Text("No matching modules").foregroundStyle(.secondary)
          }
        }
        if search.isEmpty {
          Section("Library") {
            route("Randomazzo", icon: "dice.fill", to: .randomazzo)
          }
          Section("App") {
            route("Preferences", icon: "gearshape", to: .application)
            route("About", icon: "info.circle", to: .about)
          }
        }
      }
      .listStyle(.sidebar)
      .searchable(text: $search, placement: .sidebar, prompt: "Find a module")
      .navigationSplitViewColumnWidth(min: 205, ideal: 220, max: 280)
    } detail: {
      detail.id(selection)
    }
    .toolbar {
      ToolbarItem {
        Menu {
          Button("Save current configuration…") {
            SettingsWindowController.shared.saveCurrentConfiguration()
          }
          Button("Open Randomazzo") {
            search = ""
            selection = .randomazzo
          }
        } label: {
          Label("Randomazzo", systemImage: "dice.fill")
        }
        .help("Save or browse configurations")
      }
    }
    .onReceive(
      NotificationCenter.default.publisher(for: Notification.Name("SwitchToRandomazzoTab"))
    ) { _ in
      selection = .randomazzo
    }
    .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowWidgetSettings"))) {
      notification in
      if let id = notification.object as? String { selection = .module(id) }
    }
    .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowWidgetOrder"))) {
      _ in
      selection = .widgets
    }
  }

  private func route(_ title: String, icon: String, to destination: SettingsDestination)
    -> some View
  {
    Label(title, systemImage: icon).tag(destination)
  }

  @ViewBuilder private var detail: some View {
    switch selection ?? .appearance {
    case .appearance: GeneralSettingsTab(page: .appearance)
    case .layout: GeneralSettingsTab(page: .layout)
    case .application: GeneralSettingsTab(page: .application)
    case .widgets: WidgetsSettingsTab()
    case .fonts: FontSettingsTab()
    case .module("default.spaces"): SpacesSettingsTab()
    case .module("default.time"): TimeSettingsTab()
    case .module(let id): WidgetsSettingsTab(moduleID: id)
    case .randomazzo: RandomazzoSettingsTab()
    case .about: AboutSettingsTab()
    }
  }
}
