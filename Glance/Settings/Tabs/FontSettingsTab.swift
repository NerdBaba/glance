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
                        Button("Choose Font…") {
                            openNativeFontPicker(for: .bar)
                        }
                        .buttonStyle(.borderedProminent)
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
                            Button("Choose Font…") {
                                openNativeFontPicker(for: .widget)
                            }
                            .buttonStyle(.borderedProminent)
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
    
    // MARK: - Native Font Panel
    
    private enum FontTarget {
        case bar
        case widget
    }
    
    private func openNativeFontPicker(for target: FontTarget) {
        let currentName: String?
        let currentSize: CGFloat
        
        switch target {
        case .bar:
            currentName = barFontName
            currentSize = CGFloat(barFontSize)
        case .widget:
            currentName = widgetFontName
            currentSize = CGFloat(widgetFontSize)
        }
        
        guard let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }) else {
            print("No window available for font panel")
            return
        }
        
        FontManager.shared.openFontPanel(
            initialFontName: currentName,
            initialSize: currentSize,
            parentWindow: window
        ) { [target] fontName, fontSize, weight in
            // Update state on main thread - allow continuous updates
            DispatchQueue.main.async { [self] in
                // Skip if syncing to prevent loops
                if self.isSyncing { return }
                
                self.isSyncing = true
                defer { 
                    self.isSyncing = false
                }
                
                // Validate font name (check for valid fonts)
                let validFontName = fontName.isEmpty ? "" : fontName
                
                switch target {
                case .bar:
                    self.barFontName = validFontName.isEmpty ? nil : validFontName
                    self.barFontSize = Double(fontSize)
                    self.barFontWeight = Int(weight)
                    self.configManager.updateConfigValue(key: "appearance.bar-font-name", newValue: validFontName)
                    self.configManager.updateConfigValue(key: "appearance.bar-font-size", newValue: String(Int(fontSize)))
                    self.configManager.updateConfigValue(key: "appearance.bar-font-weight", newValue: String(Int(weight)))
                    
                case .widget:
                    self.widgetFontName = validFontName.isEmpty ? nil : validFontName
                    self.widgetFontSize = Double(fontSize)
                    self.widgetFontWeight = Int(weight)
                    self.configManager.updateConfigValue(key: "appearance.widget-font-name", newValue: validFontName)
                    self.configManager.updateConfigValue(key: "appearance.widget-font-size", newValue: String(Int(fontSize)))
                    self.configManager.updateConfigValue(key: "appearance.widget-font-weight", newValue: String(Int(weight)))
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func resetFont(for target: FontTarget) {
        isSyncing = true
        defer { isSyncing = false }
        
        switch target {
        case .bar:
            barFontName = nil
            configManager.updateConfigValue(key: "appearance.bar-font-name", newValue: "")
            
        case .widget:
            widgetFontName = nil
            configManager.updateConfigValue(key: "appearance.widget-font-name", newValue: "")
        }
    }
    
    private func resetAllFonts() {
        isSyncing = true
        defer { isSyncing = false }
        
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
        
        // Only update if values are actually different (prevents fighting with user input)
        if barFontName != appearance.barFont.fontName {
            barFontName = appearance.barFont.fontName
        }
        if abs(barFontSize - Double(appearance.barFont.fontSize)) > 0.1 {
            barFontSize = Double(appearance.barFont.fontSize)
        }
        if barFontWeight != appearance.barFont.weight.toInt() {
            barFontWeight = appearance.barFont.weight.toInt()
        }
        
        if widgetFontName != appearance.widgetFont.fontName {
            widgetFontName = appearance.widgetFont.fontName
        }
        if abs(widgetFontSize - Double(appearance.widgetFont.fontSize)) > 0.1 {
            widgetFontSize = Double(appearance.widgetFont.fontSize)
        }
        if widgetFontWeight != appearance.widgetFont.weight.toInt() {
            widgetFontWeight = appearance.widgetFont.weight.toInt()
        }
        
        if useSingleFont != appearance.useSingleFont {
            useSingleFont = appearance.useSingleFont
        }
    }
}

#Preview {
    FontSettingsTab()
}
