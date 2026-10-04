import SwiftUI

struct SettingsSection<Content: View>: View {
  let title: String
  var subtitle: String? = nil
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      VStack(alignment: .leading, spacing: 5) {
        Text(title).font(.headline)
        if let subtitle {
          Text(subtitle).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      VStack(alignment: .leading, spacing: 16) { content }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
    }
  }
}

struct SliderRow: View {
  let label: String
  @Binding var value: Double
  let range: ClosedRange<Double>
  var step: Double = 1
  var format: String = "%.0f"
  var onCommit: () -> Void = {}

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .firstTextBaseline) {
        Text(label).fixedSize(horizontal: false, vertical: true)
        Spacer(minLength: 16)
        Text(String(format: format, value))
          .monospacedDigit().foregroundStyle(.secondary)
      }
      Slider(
        value: $value, in: range, step: step,
        onEditingChanged: { editing in
          if !editing { onCommit() }
        }
      )
      .accessibilityLabel(label)
    }
  }
}

struct SettingsPage<Content: View>: View {
  @ViewBuilder let content: Content

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 28) { content }
        .frame(maxWidth: 780, alignment: .leading)
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
    .background(Color(nsColor: .windowBackgroundColor))
  }
}

struct SettingsPageHeader: View {
  let title: String
  let summary: String

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title).font(.system(size: 25, weight: .semibold))
      Text(summary).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }
}

struct ModuleSettingsHeader: View {
  let id: String
  @ObservedObject private var configManager = ConfigManager.shared

  var body: some View {
    let module = SettingsModule.descriptor(for: id)
    let active = configManager.config.rootToml.widgets?.displayed.contains { $0.id == id } == true
    VStack(alignment: .leading, spacing: 14) {
      SettingsPageHeader(title: module.title, summary: module.summary)
      HStack {
        Label(
          active ? "In your bar" : "Not in your bar",
          systemImage: active ? "checkmark.circle.fill" : "circle.dashed"
        )
        .font(.callout).foregroundStyle(.secondary)
        Spacer()
        Button("Edit widget order") {
          NotificationCenter.default.post(name: Notification.Name("ShowWidgetOrder"), object: nil)
        }
      }
    }
  }
}

/// Writes only in response to a control's setter. Reading a module page never
/// creates overrides for inherited defaults.
struct ModuleSettingsEditor {
  let id: String
  var manager: ConfigManager { .shared }
  var values: ConfigData { manager.globalWidgetConfig(for: id) }

  func string(_ key: String, default fallback: String = "", removeEmpty: Bool = false) -> Binding<
    String
  > {
    Binding(
      get: { values[key]?.stringValue ?? fallback },
      set: { value in
        guard value != (values[key]?.stringValue ?? fallback) else { return }
        if removeEmpty && value.isEmpty {
          manager.removeConfigValue(key: "widgets.\(id).\(key)")
        } else {
          manager.updateConfigValue(key: "widgets.\(id).\(key)", newValue: Self.quoted(value))
        }
      })
  }

  func number(_ key: String, default fallback: Double) -> Binding<Double> {
    Binding(
      get: { values[key]?.doubleValue ?? fallback },
      set: { value in
        guard abs(value - (values[key]?.doubleValue ?? fallback)) > 0.0001 else { return }
        manager.updateConfigValue(key: "widgets.\(id).\(key)", newValue: String(value))
      })
  }

  func integer(_ key: String, default fallback: Int) -> Binding<Int> {
    Binding(
      get: { values[key]?.intValue ?? fallback },
      set: { value in
        guard value != (values[key]?.intValue ?? fallback) else { return }
        manager.updateConfigValue(key: "widgets.\(id).\(key)", newValue: String(value))
      })
  }

  func bool(_ key: String, default fallback: Bool = false) -> Binding<Bool> {
    Binding(
      get: { values[key]?.boolValue ?? fallback },
      set: { value in
        guard value != (values[key]?.boolValue ?? fallback) else { return }
        manager.updateConfigValue(key: "widgets.\(id).\(key)", newValue: value ? "true" : "false")
      })
  }

  static func quoted(_ text: String) -> String {
    "\""
      + text.replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
      .replacingOccurrences(of: "\n", with: "\\n")
      .replacingOccurrences(of: "\r", with: "\\r")
      .replacingOccurrences(of: "\t", with: "\\t") + "\""
  }
}

/// Commit text after Return or focus loss, so incomplete commands and font
/// names are not applied while the user is typing.
struct SettingsTextField: View {
  let label: String
  @Binding var value: String
  var prompt: String = ""
  var fontName: String? = nil
  @State private var draft = ""
  @FocusState private var focused: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(label).font(.callout)
      TextField(prompt, text: $draft)
        .font(fontName.map { .custom($0, size: 14) } ?? .body)
        .textFieldStyle(.roundedBorder)
        .focused($focused)
        .onSubmit { commit() }
        .onChange(of: focused) { _, isFocused in if !isFocused { commit() } }
    }
    .onAppear { draft = value }
    .onChange(of: value) { _, value in if !focused { draft = value } }
    .onDisappear { commit() }
  }

  private func commit() {
    if draft != value { value = draft }
  }
}

struct ModuleSlider: View {
  let label: String
  @Binding var value: Double
  let range: ClosedRange<Double>
  var step: Double = 1
  var format: String = "%.0f pt"

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text(label)
        Spacer()
        Text(String(format: format, value)).monospacedDigit().foregroundStyle(.secondary)
      }
      Slider(value: $value, in: range, step: step).accessibilityLabel(label)
    }
  }
}
