import SwiftUI

struct FontSettingsTab: View {
    @ObservedObject var configManager = ConfigManager.shared
    @State private var isSyncing = false
    
    // Bar font state
    @State private var barFontName: String?
    @State private var barFontSize: Double
    @State private var barFontWeight: Int
    
    // Widget font state
    @State private var widgetFontName: String?
    @State private var widgetFontSize: Double
    @State private var widgetFontWeight: Int
    
    // Single font mode
    @State private var useSingleFont: Bool
    
    // Font picker state
    @State private var showingBarFontPicker = false
    @State private var showingWidgetFontPicker = false
    @State private var availableFonts: [String] = []
    
    init() {
        let appearance = ConfigManager.shared.config.appearance
        
        // Bar font
        _barFontName = State(initialValue: appearance.barFont.fontName)
        _barFontSize = State(initialValue: Double(appearance.barFont.fontSize))
        _barFontWeight = State(initialValue: appearance.barFont.weight.toInt())
        
        // Widget font
        _widgetFontName = State(initialValue: appearance.widgetFont.fontName)
        _widgetFontSize = State(initialValue: Double(appearance.widgetFont.fontSize))
        _widgetFontWeight = State(initialValue: appearance.widgetFont.weight.toInt())
        
        // Single font mode
        _useSingleFont = State(initialValue: appearance.useSingleFont)
        
        // Load available fonts
        _availableFonts = State(initialValue: FontManager.shared.availableFontFamilies())
    }
    
    var body: some View {
        Form {
            Section {
                Toggle("Use Single Font for Bar and Widgets", isOn: $useSingleFont)
                    .onChange(of: useSingleFont) { _, newValue in
                        guard !isSyncing else { return }
                        configManager.updateConfigValue(key: "appearance.use-single-font", newValue: String(newValue))
                    }
                
                Text("When enabled, widgets will use the same font as the bar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Bar Font")
                            .fontWeight(.medium)
                        Spacer()
                        Menu {
                            Button("System Font") {
                                selectFont(nil, for: .bar)
                            }
                            
                            Divider()
                            
                            ForEach(availableFonts, id: \.self) { fontName in
                                Button(fontName) {
                                    selectFont(fontName, for: .bar)
                                }
                            }
                        } label: {
                            Label("Choose Font", systemImage: "chevron.down")
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize(horizontal: true, vertical: false)
                    }
                    
                    fontPreviewRow(
                        fontName: barFontName,
                        fontSize: barFontSize,
                        weight: barFontWeight,
                        label: "Preview"
                    )
                    
                    HStack {
                        Text("Size")
                        Slider(value: $barFontSize, in: 8...24, step: 0.5)
                            .frame(width: 150)
                            .onChange(of: barFontSize) { _, newValue in
                                guard !isSyncing else { return }
                                configManager.updateConfigValue(key: "appearance.bar-font-size", newValue: String(Int(newValue)))
                            }
                        Text("\(barFontSize, specifier: "%.1f") pt")
                            .monospacedDigit()
                            .frame(width: 50)
                    }
                    
                    HStack {
                        Text("Weight")
                        Picker("Weight", selection: $barFontWeight) {
                            ForEach(0...8, id: \.self) { weight in
                                Text(weightName(for: weight)).tag(weight)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: barFontWeight) { _, newValue in
                            guard !isSyncing else { return }
                            configManager.updateConfigValue(key: "appearance.bar-font-weight", newValue: String(newValue))
                        }
                    }
                    
                    if barFontName != nil {
                        Button("Reset to System Font") {
                            resetFont(for: .bar)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(.vertical, 8)
            }
            
            if !useSingleFont {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Widget Font")
                                .fontWeight(.medium)
                            Spacer()
                            Menu {
                                Button("System Font") {
                                    selectFont(nil, for: .widget)
                                }
                                
                                Divider()
                                
                                ForEach(availableFonts, id: \.self) { fontName in
                                    Button(fontName) {
                                        selectFont(fontName, for: .widget)
                                    }
                                }
                            } label: {
                                Label("Choose Font", systemImage: "chevron.down")
                            }
                            .menuStyle(.borderlessButton)
                            .fixedSize(horizontal: true, vertical: false)
                        }
                        
                        fontPreviewRow(
                            fontName: widgetFontName,
                            fontSize: widgetFontSize,
                            weight: widgetFontWeight,
                            label: "Preview"
                        )
                        
                        HStack {
                            Text("Size")
                            Slider(value: $widgetFontSize, in: 8...24, step: 0.5)
                                .frame(width: 150)
                                .onChange(of: widgetFontSize) { _, newValue in
                                    guard !isSyncing else { return }
                                    configManager.updateConfigValue(key: "appearance.widget-font-size", newValue: String(Int(newValue)))
                                }
                            Text("\(widgetFontSize, specifier: "%.1f") pt")
                                .monospacedDigit()
                                .frame(width: 50)
                        }
                        
                        HStack {
                            Text("Weight")
                            Picker("Weight", selection: $widgetFontWeight) {
                                ForEach(0...8, id: \.self) { weight in
                                    Text(weightName(for: weight)).tag(weight)
                                }
                            }
                            .pickerStyle(.menu)
                            .onChange(of: widgetFontWeight) { _, newValue in
                                guard !isSyncing else { return }
                                configManager.updateConfigValue(key: "appearance.widget-font-weight", newValue: String(newValue))
                            }
                        }
                        
                        if widgetFontName != nil {
                            Button("Reset to System Font") {
                                resetFont(for: .widget)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            
            Section {
                Button("Reset All Fonts to Default") {
                    resetAllFonts()
                }
                .buttonStyle(.borderless)
            }
        }
        .formStyle(.grouped)
        .animation(.smooth, value: useSingleFont)
        .onReceive(configManager.$config) { _ in
            syncFromConfig()
        }
    }
    
    // MARK: - Font Preview
    
    @ViewBuilder
    private func fontPreviewRow(
        fontName: String?,
        fontSize: Double,
        weight: Int,
        label: String
    ) -> some View {
        let previewText = fontName ?? "System Font"
        let weightValue = Font.Weight.fromInt(weight) ?? .regular
        let font = fontName.map { Font.custom($0, size: fontSize).weight(weightValue) }
            ?? Font.system(size: fontSize, weight: weightValue)
        
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Text(previewText)
                .font(font)
                .lineLimit(1)
            Spacer()
        }
        .frame(height: 24)
    }
    
    // MARK: - Actions
    
    private enum FontTarget {
        case bar
        case widget
    }
    
    private func selectFont(_ fontName: String?, for target: FontTarget) {
        switch target {
        case .bar:
            barFontName = fontName
            configManager.updateConfigValue(key: "appearance.bar-font-name", newValue: fontName ?? "")
            
        case .widget:
            widgetFontName = fontName
            configManager.updateConfigValue(key: "appearance.widget-font-name", newValue: fontName ?? "")
        }
    }
    
    private func resetFont(for target: FontTarget) {
        selectFont(nil, for: target)
    }
    
    private func resetAllFonts() {
        barFontName = nil
        barFontSize = 13
        barFontWeight = 4 // medium
        
        widgetFontName = nil
        widgetFontSize = 13
        widgetFontWeight = 4 // medium
        
        useSingleFont = true
        
        configManager.updateConfigValue(key: "appearance.bar-font-name", newValue: "")
        configManager.updateConfigValue(key: "appearance.bar-font-size", newValue: String(13))
        configManager.updateConfigValue(key: "appearance.bar-font-weight", newValue: String(5))
        configManager.updateConfigValue(key: "appearance.widget-font-name", newValue: "")
        configManager.updateConfigValue(key: "appearance.widget-font-size", newValue: String(13))
        configManager.updateConfigValue(key: "appearance.widget-font-weight", newValue: String(5))
        configManager.updateConfigValue(key: "appearance.use-single-font", newValue: String(true))
    }
    
    private func updateConfigValue(key: String, stringValue: String) {
        isSyncing = true
        defer { isSyncing = false }
        configManager.updateConfigValue(key: key, newValue: stringValue)
    }
    
    // MARK: - Helpers
    
    private func weightName(for value: Int) -> String {
        switch value {
        case 0: return "Thin"
        case 1: return "Ultra Light"
        case 2: return "Light"
        case 3: return "Regular"
        case 4: return "Medium"
        case 5: return "Semibold"
        case 6: return "Bold"
        case 7: return "Heavy"
        case 8: return "Black"
        default: return "Regular"
        }
    }
    
    private func syncFromConfig() {
        guard !isSyncing else { return }
        let appearance = configManager.config.appearance
        
        barFontName = appearance.barFont.fontName
        barFontSize = Double(appearance.barFont.fontSize)
        barFontWeight = appearance.barFont.weight.toInt()
        
        widgetFontName = appearance.widgetFont.fontName
        widgetFontSize = Double(appearance.widgetFont.fontSize)
        widgetFontWeight = appearance.widgetFont.weight.toInt()
        
        useSingleFont = appearance.useSingleFont
    }
}

#Preview {
    FontSettingsTab()
}
