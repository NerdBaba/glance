import SwiftUI

enum WidgetSettingsArea: String, CaseIterable, Identifiable {
  case content = "Content", appearance = "Appearance", behavior = "Behavior", advanced = "Advanced"
  var id: String { rawValue }
  var summary: String {
    switch self {
    case .content: "Choose what this widget shows. Changes appear in the preview."
    case .appearance: "Adjust icons, colors, size, and font."
    case .behavior: "Choose what happens when you click or scroll."
    case .advanced: "Fine alignment, custom layouts, data sources, and individual component options."
    }
  }
}

private struct WidgetSettingsAreaKey: EnvironmentKey { static let defaultValue: WidgetSettingsArea? = nil }
private struct SettingsSearchQueryKey: EnvironmentKey { static let defaultValue = "" }
extension EnvironmentValues {
  var widgetSettingsArea: WidgetSettingsArea? {
    get { self[WidgetSettingsAreaKey.self] }
    set { self[WidgetSettingsAreaKey.self] = newValue }
  }
  var settingsSearchQuery: String {
    get { self[SettingsSearchQueryKey.self] }
    set { self[SettingsSearchQueryKey.self] = newValue }
  }
}

struct SettingsSearchField: View {
  @Binding var text: String
  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
      TextField("Find a setting…", text: $text).textFieldStyle(.plain)
        .accessibilityLabel("Find a setting")
      if !text.isEmpty {
        Button { text = "" } label: { Image(systemName: "xmark.circle.fill") }
          .buttonStyle(.plain).foregroundStyle(.secondary).accessibilityLabel("Clear settings search")
      }
    }
    .padding(9).background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
  }
}

struct WidgetSettingsNavigation: View {
  let id: String
  @Binding var area: WidgetSettingsArea
  @Binding var query: String
  @ObservedObject private var manager = ConfigManager.shared
  private var values: ConfigData { manager.globalWidgetConfig(for: id) }
  private var areas: [WidgetSettingsArea] {
    if GlanceTransitionWidget.isDecoration(values) { return [.content, .advanced] }
    let hasBehavior = id.hasPrefix("script.") || ["default.battery", "default.volume", "default.brightness", "default.time"].contains(id)
    return [.content, .appearance] + (hasBehavior ? [.behavior] : []) + [.advanced]
  }
  var body: some View {
    let module = SettingsModule.descriptor(for: id, config: manager.config)
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: module.icon).font(.title2).foregroundStyle(Color.accentColor)
          .frame(width: 38, height: 38).background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        VStack(alignment: .leading, spacing: 4) {
          Text(module.title).font(.system(size: 22, weight: .semibold))
          Text(module.summary).font(.callout).foregroundStyle(.secondary).lineLimit(2)
        }
        Spacer()
        Button("Widget order", systemImage: "list.bullet") {
          NotificationCenter.default.post(name: Notification.Name("ShowWidgetOrder"), object: nil)
        }.labelStyle(.iconOnly).help("Arrange the widgets in your bar")
      }
      WidgetSettingsPreview(id: id)
      HStack(spacing: 12) {
        Picker("Customize", selection: $area) {
          ForEach(areas) { area in Text(area.rawValue).tag(area) }
        }.pickerStyle(.segmented).accessibilityLabel("Widget settings category")
      }
      SettingsSearchField(text: $query)
      Text(query.isEmpty ? area.summary : "Showing matches across all categories.")
        .font(.caption).foregroundStyle(.secondary)
    }
    .padding(.horizontal, 28).padding(.top, 22).padding(.bottom, 16)
    .background(Color(nsColor: .windowBackgroundColor))
    .overlay(alignment: .bottom) { Divider() }
  }
}

private struct WidgetSettingsPreview: View {
  let id: String
  @ObservedObject private var manager = ConfigManager.shared
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("PREVIEW").font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(.secondary)
      if id.hasPrefix("script.") {
        GlanceModulePreview(values: manager.globalWidgetConfig(for: id))
      } else {
        let appearance = manager.config.appearance
        HStack {
          MenuBarView(configManager: manager)
            .moduleView(for: TomlWidgetItem(id: id, inlineParams: [:]), height: 36)
            .frame(height: 36)
            .environment(\.appearance, appearance)
            .environment(\.barStyle, manager.config.barStyle)
            .environment(\.barFont, appearance.barFont)
            .environment(\.widgetFont, appearance.useSingleFont ? appearance.barFont : appearance.widgetFont)
            .environment(\.isBarPreviewRendering, true)
            .foregroundStyle(appearance.foregroundColor)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(appearance.widgetBackgroundColor, in: RoundedRectangle(cornerRadius: 9))
          Spacer(minLength: 0)
        }
        .allowsHitTesting(false).accessibilityLabel("Widget appearance preview")
      }
    }
  }
}

struct SettingsSearchMatches: PreferenceKey {
  static let defaultValue: Set<String> = []
  static func reduce(value: inout Set<String>, nextValue: () -> Set<String>) { value.formUnion(nextValue()) }
}
