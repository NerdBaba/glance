import SwiftUI

struct FontSettingsTab: View {
    @ObservedObject var configManager = ConfigManager.shared
    @State private var isSyncing = false
    
    // Single font state (applies to both bar and widgets)
    @State private var fontName: String?
    @State private var fontSize: Double
    @State private var fontWeight: Int
    
    init() {
        let appearance = ConfigManager.shared.config.appearance
        
        // Use bar font as the primary font
        _fontName = State(initialValue: appearance.barFont.fontName)
        _fontSize = State(initialValue: Double(appearance.barFont.fontSize))
        _fontWeight = State(initialValue: appearance.barFont.weight.toInt())
    }
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Font")
                            .fontWeight(.medium)
                        Spacer()
                        Button("Choose Font…") {
                            openNativeFontPicker()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                    fontPreviewRow(
                        fontName: fontName,
                        fontSize: fontSize,
                        weight: fontWeight,
                        label: "Preview"
                    )
                    
                    HStack {
                        Text("Size")
                        Slider(value: $fontSize, in: 8...24, step: 0.5)
                            .frame(width: 150)
                            .onChange(of: fontSize) { _, newValue in
                                guard !isSyncing else { return }
                                configManager.updateConfigValue(key: "appearance.bar-font-size", newValue: String(Int(newValue)))
                                configManager.updateConfigValue(key: "appearance.widget-font-size", newValue: String(Int(newValue)))
                            }
                        Text("\(fontSize, specifier: "%.1f") pt")
                            .monospacedDigit()
                            .frame(width: 50)
                    }
                    
                    HStack {
                        Text("Weight")
                        Picker("Weight", selection: $fontWeight) {
                            ForEach(0...8, id: \.self) { weight in
                                Text(weightName(for: weight)).tag(weight)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: fontWeight) { _, newValue in
                            guard !isSyncing else { return }
                            configManager.updateConfigValue(key: "appearance.bar-font-weight", newValue: String(newValue))
                            configManager.updateConfigValue(key: "appearance.widget-font-weight", newValue: String(newValue))
                        }
                    }
                    
                    if fontName != nil {
                        Button("Reset to System Font") {
                            resetFont()
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(.vertical, 8)
            }
            
            Section {
                Button("Reset Font to Default") {
                    resetFont()
                }
                .buttonStyle(.borderless)
            }
        }
        .formStyle(.grouped)
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
    
    private func openNativeFontPicker() {
        guard let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }) else {
            print("No window available for font panel")
            return
        }
        
        FontManager.shared.openFontPanel(
            initialFontName: fontName,
            initialSize: CGFloat(fontSize),
            parentWindow: window
        ) { fontName, fontSize, weight in
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
                
                self.fontName = validFontName.isEmpty ? nil : validFontName
                self.fontSize = Double(fontSize)
                self.fontWeight = Int(weight)
                
                // Update both bar and widget font settings
                self.configManager.updateConfigValue(key: "appearance.bar-font-name", newValue: validFontName)
                self.configManager.updateConfigValue(key: "appearance.bar-font-size", newValue: String(Int(fontSize)))
                self.configManager.updateConfigValue(key: "appearance.bar-font-weight", newValue: String(Int(weight)))
                self.configManager.updateConfigValue(key: "appearance.widget-font-name", newValue: validFontName)
                self.configManager.updateConfigValue(key: "appearance.widget-font-size", newValue: String(Int(fontSize)))
                self.configManager.updateConfigValue(key: "appearance.widget-font-weight", newValue: String(Int(weight)))
            }
        }
    }
    
    // MARK: - Actions
    
    private func resetFont() {
        isSyncing = true
        defer { isSyncing = false }
        
        fontName = nil
        fontSize = 13
        fontWeight = 4 // medium
        
        configManager.updateConfigValue(key: "appearance.bar-font-name", newValue: "")
        configManager.updateConfigValue(key: "appearance.bar-font-size", newValue: String(13))
        configManager.updateConfigValue(key: "appearance.bar-font-weight", newValue: String(5))
        configManager.updateConfigValue(key: "appearance.widget-font-name", newValue: "")
        configManager.updateConfigValue(key: "appearance.widget-font-size", newValue: String(13))
        configManager.updateConfigValue(key: "appearance.widget-font-weight", newValue: String(5))
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
        if fontName != appearance.barFont.fontName {
            fontName = appearance.barFont.fontName
        }
        if abs(fontSize - Double(appearance.barFont.fontSize)) > 0.1 {
            fontSize = Double(appearance.barFont.fontSize)
        }
        if fontWeight != appearance.barFont.weight.toInt() {
            fontWeight = appearance.barFont.weight.toInt()
        }
    }
}

#Preview {
    FontSettingsTab()
}
