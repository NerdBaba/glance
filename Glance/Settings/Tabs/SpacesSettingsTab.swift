import SwiftUI

struct SpacesSettingsTab: View {
    @ObservedObject var configManager = ConfigManager.shared

    @State private var showKey: Bool = true
    @State private var showTitle: Bool = true
    @State private var maxLength: Double = 50
    @State private var selectedDisplayMode: String = "icons"
    @State private var selectedHighlight: String = "opacity"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // MARK: - Display Mode
                SettingsSection(title: "Display Mode") {
                    SpacesDisplayModePicker(selected: $selectedDisplayMode)
                        .onChange(of: selectedDisplayMode) { _, newValue in
                            configManager.updateConfigValue(
                                key: "widgets.default.spaces.space.display-mode",
                                newValue: newValue)
                        }
                }

                // MARK: - Highlight Style
                SettingsSection(title: "Highlight Style") {
                    SpacesHighlightPicker(selected: $selectedHighlight)
                        .onChange(of: selectedHighlight) { _, newValue in
                            configManager.updateConfigValue(
                                key: "widgets.default.spaces.space.highlight",
                                newValue: newValue)
                        }
                }

                // MARK: - Space Indicators
                SettingsSection(title: "Space Indicators") {
                    Toggle("Show space number / key", isOn: $showKey)
                        .onChange(of: showKey) { _, newValue in
                            configManager.updateConfigValue(
                                key: "widgets.default.spaces.space.show-key",
                                newValue: newValue ? "true" : "false")
                        }
                }

                // MARK: - Window Titles
                SettingsSection(title: "Window Titles") {
                    Toggle("Show focused window title", isOn: $showTitle)
                        .onChange(of: showTitle) { _, newValue in
                            configManager.updateConfigValue(
                                key: "widgets.default.spaces.window.show-title",
                                newValue: newValue ? "true" : "false")
                        }
                    SliderRow(label: "Max title length", value: $maxLength, range: 10...100, step: 5, format: "%.0f") {
                        configManager.updateConfigValue(
                            key: "widgets.default.spaces.window.title.max-length",
                            newValue: String(Int(maxLength)))
                    }
                }

                Spacer()
            }
            .padding(24)
        }
        .onAppear { syncFromConfig() }
    }

    private func syncFromConfig() {
        let spacesConfig = configManager.globalWidgetConfig(for: "default.spaces")
        let spaceSection = spacesConfig["space"]?.dictionaryValue ?? [:]
        let windowSection = spacesConfig["window"]?.dictionaryValue ?? [:]
        let titleSection = windowSection["title"]?.dictionaryValue ?? [:]

        showKey = spaceSection["show-key"]?.boolValue ?? true
        showTitle = windowSection["show-title"]?.boolValue ?? true
        maxLength = Double(titleSection["max-length"]?.intValue ?? 50)
        selectedDisplayMode = spaceSection["display-mode"]?.stringValue ?? "icons"
        selectedHighlight = spaceSection["highlight"]?.stringValue ?? "opacity"
    }
}

// MARK: - Display Mode Picker

private struct SpacesDisplayModePicker: View {
    @Binding var selected: String

    private let modes: [(id: String, label: String, icon: String, desc: String)] = [
        ("icons", "Icons", "square.grid.2x2", "Number + app icons"),
        ("numbers", "Numbers", "textformat.123", "Space numbers only"),
        ("dots", "Dots", "circle.grid.3x3", "Minimal dot indicators"),
        ("icons-only", "Icons Only", "app.dashed", "App icons, no numbers"),
        ("focused-only", "Focused", "scope", "Only current space"),
    ]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(modes, id: \.id) { mode in
                SpacesOptionCard(
                    id: mode.id,
                    label: mode.label,
                    isSelected: selected == mode.id
                ) {
                    SpacesDisplayDiagram(mode: mode.id)
                        .frame(height: 24)
                } action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selected = mode.id
                    }
                }
            }
        }
    }
}

// MARK: - Highlight Style Picker

private struct SpacesHighlightPicker: View {
    @Binding var selected: String

    private let styles: [(id: String, label: String)] = [
        ("opacity", "Opacity"),
        ("pill", "Pill"),
        ("underline", "Underline"),
        ("glow", "Glow"),
    ]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(styles, id: \.id) { style in
                SpacesOptionCard(
                    id: style.id,
                    label: style.label,
                    isSelected: selected == style.id
                ) {
                    SpacesHighlightDiagram(style: style.id)
                        .frame(height: 24)
                } action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selected = style.id
                    }
                }
            }
        }
    }
}

// MARK: - Shared Card Component

private struct SpacesOptionCard<Diagram: View>: View {
    let id: String
    let label: String
    let isSelected: Bool
    @ViewBuilder let diagram: Diagram
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                diagram
                Text(label)
                    .font(.caption2)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        isSelected ? Color.accentColor : Color.white.opacity(0.08),
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Display Mode Diagrams

private struct SpacesDisplayDiagram: View {
    let mode: String

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            switch mode {
            case "icons":
                iconsDiagram(w: w, h: h)
            case "numbers":
                numbersDiagram(w: w, h: h)
            case "dots":
                dotsDiagram(w: w, h: h)
            case "icons-only":
                iconsOnlyDiagram(w: w, h: h)
            case "focused-only":
                focusedOnlyDiagram(w: w, h: h)
            default:
                EmptyView()
            }
        }
    }

    // Icons mode: number + squares representing app icons
    @ViewBuilder
    private func iconsDiagram(w: CGFloat, h: CGFloat) -> some View {
        HStack(spacing: 6) {
            // Space 1: number + 2 icons
            HStack(spacing: 3) {
                Text("1")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 8, height: 8)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 8, height: 8)
            }
            // Space 2: number + 1 icon (dimmed)
            HStack(spacing: 3) {
                Text("2")
                    .font(.system(size: 8, weight: .regular, design: .rounded))
                    .foregroundStyle(.gray)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
            .opacity(0.6)
        }
        .frame(width: w, height: h)
    }

    // Numbers mode: just space numbers
    @ViewBuilder
    private func numbersDiagram(w: CGFloat, h: CGFloat) -> some View {
        HStack(spacing: 6) {
            ForEach(1...4, id: \.self) { num in
                Text("\(num)")
                    .font(.system(size: 9, weight: num == 1 ? .bold : .regular, design: .rounded))
                    .foregroundStyle(num == 1 ? .white : .gray)
                    .opacity(num == 1 ? 1.0 : 0.5)
            }
        }
        .frame(width: w, height: h)
    }

    // Dots mode: circles
    @ViewBuilder
    private func dotsDiagram(w: CGFloat, h: CGFloat) -> some View {
        HStack(spacing: 5) {
            // Focused + occupied
            Circle()
                .fill(Color.accentColor)
                .frame(width: 7, height: 7)
            // Occupied
            Circle()
                .fill(Color.white.opacity(0.6))
                .frame(width: 5, height: 5)
            // Empty
            Circle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 5, height: 5)
            // Occupied
            Circle()
                .fill(Color.white.opacity(0.6))
                .frame(width: 5, height: 5)
        }
        .frame(width: w, height: h)
    }

    // Icons only: just squares
    @ViewBuilder
    private func iconsOnlyDiagram(w: CGFloat, h: CGFloat) -> some View {
        HStack(spacing: 6) {
            // Space 1: 2 icon squares
            HStack(spacing: 2) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.7))
                    .frame(width: 8, height: 8)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.7))
                    .frame(width: 8, height: 8)
            }
            // Space 2: 1 icon (dimmed)
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.white.opacity(0.3))
                .frame(width: 8, height: 8)
            // Space 3: empty dot
            Circle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 5, height: 5)
        }
        .frame(width: w, height: h)
    }

    // Focused only: single space indicator
    @ViewBuilder
    private func focusedOnlyDiagram(w: CGFloat, h: CGFloat) -> some View {
        HStack(spacing: 3) {
            Text("3")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.white.opacity(0.6))
                .frame(width: 8, height: 8)
        }
        .frame(width: w, height: h)
    }
}

// MARK: - Highlight Style Diagrams

private struct SpacesHighlightDiagram: View {
    let style: String

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            switch style {
            case "opacity":
                opacityDiagram(w: w, h: h)
            case "pill":
                pillDiagram(w: w, h: h)
            case "underline":
                underlineDiagram(w: w, h: h)
            case "glow":
                glowDiagram(w: w, h: h)
            default:
                EmptyView()
            }
        }
    }

    // Opacity: focused bright, others dimmed
    @ViewBuilder
    private func opacityDiagram(w: CGFloat, h: CGFloat) -> some View {
        HStack(spacing: 5) {
            Circle().fill(Color.white.opacity(0.3)).frame(width: 6, height: 6)
            Circle().fill(Color.white).frame(width: 7, height: 7)
            Circle().fill(Color.white.opacity(0.3)).frame(width: 6, height: 6)
        }
        .frame(width: w, height: h)
    }

    // Pill: focused has background capsule
    @ViewBuilder
    private func pillDiagram(w: CGFloat, h: CGFloat) -> some View {
        HStack(spacing: 5) {
            Circle().fill(Color.white.opacity(0.4)).frame(width: 6, height: 6)
            Circle().fill(Color.white).frame(width: 7, height: 7)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(
                    Capsule().fill(Color.accentColor.opacity(0.3))
                        .overlay(Capsule().strokeBorder(Color.accentColor.opacity(0.4), lineWidth: 0.5))
                )
            Circle().fill(Color.white.opacity(0.4)).frame(width: 6, height: 6)
        }
        .frame(width: w, height: h)
    }

    // Underline: focused has bar below
    @ViewBuilder
    private func underlineDiagram(w: CGFloat, h: CGFloat) -> some View {
        HStack(spacing: 5) {
            Circle().fill(Color.white.opacity(0.4)).frame(width: 6, height: 6)
            VStack(spacing: 2) {
                Circle().fill(Color.white).frame(width: 7, height: 7)
                RoundedRectangle(cornerRadius: 0.5)
                    .fill(Color.accentColor)
                    .frame(width: 10, height: 2)
            }
            Circle().fill(Color.white.opacity(0.4)).frame(width: 6, height: 6)
        }
        .frame(width: w, height: h)
    }

    // Glow: focused has soft glow
    @ViewBuilder
    private func glowDiagram(w: CGFloat, h: CGFloat) -> some View {
        HStack(spacing: 5) {
            Circle().fill(Color.white.opacity(0.3)).frame(width: 6, height: 6)
            Circle().fill(Color.white).frame(width: 7, height: 7)
                .shadow(color: Color.accentColor.opacity(0.8), radius: 4)
            Circle().fill(Color.white.opacity(0.3)).frame(width: 6, height: 6)
        }
        .frame(width: w, height: h)
    }
}
