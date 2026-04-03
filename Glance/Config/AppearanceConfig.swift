import SwiftUI

/// Font configuration for bar and widgets.
struct FontConfig: Equatable {
    var fontName: String?      // nil = system default
    var fontSize: CGFloat
    var weight: Font.Weight
    
    /// Create a custom font from the config (includes weight).
    func toFont() -> Font {
        if let fontName = fontName, !fontName.isEmpty {
            return Font.custom(fontName, size: fontSize).weight(weight)
        } else {
            return Font.system(size: fontSize, weight: weight)
        }
    }
    
    /// Apply weight to the font (deprecated - use toFont() which includes weight).
    func withWeight(_ weight: Font.Weight) -> Font {
        if let fontName = fontName, !fontName.isEmpty {
            return Font.custom(fontName, size: fontSize, relativeTo: .body).weight(weight)
        } else {
            return Font.system(size: fontSize, weight: weight)
        }
    }
}

/// All visual parameters for widget/popup rendering.
/// Resolved from a preset + optional user overrides.
struct AppearanceConfig {
    let renderingStyle: BarStyle
    let roundness: CGFloat          // 0 = square, 50 = capsule
    let borderWidth: CGFloat
    let borderTopOpacity: CGFloat
    let borderMidOpacity: CGFloat
    let borderBottomOpacity: CGFloat
    let fillOpacity: CGFloat
    let glowOpacity: CGFloat
    let glowRadius: CGFloat
    let shadowOpacity: CGFloat
    let shadowRadius: CGFloat
    let shadowY: CGFloat
    let blurMaterial: NSVisualEffectView.Material
    let popupDarkTint: CGFloat
    let popupRoundness: CGFloat

    // Colors
    let foregroundColor: Color
    let accentColor: Color
    let borderColor: Color
    let borderColor2: Color?        // Non-nil = gradient border
    let widgetBackgroundColor: Color
    let glowColor: Color
    
    // Typography
    let barFont: FontConfig
    let widgetFont: FontConfig
    let useSingleFont: Bool         // If true, widgetFont = barFont

    /// Maps roundness (0-50) to a concrete cornerRadius for widget capsules.
    func resolvedWidgetCornerRadius(height: CGFloat = 38) -> CGFloat {
        let clamped = min(max(roundness, 0), 50)
        let maxRadius = height / 2
        return maxRadius * (clamped / 50)
    }

    /// Maps popupRoundness to a concrete cornerRadius for popups.
    func resolvedPopupCornerRadius() -> CGFloat {
        popupRoundness
    }

    /// Creates a copy with user overrides applied.
    func applying(overrides: AppearanceOverrides?) -> AppearanceConfig {
        guard let o = overrides else { return self }

        // Parse custom colors
        let customForeground = o.foregroundColor.flatMap { Self.parseHex($0) }
        let customAccent = o.accentColor.flatMap { Self.parseHex($0) }
        let customWidgetBg = o.widgetBackgroundColor.flatMap { Self.parseHex($0) }
        let customBorder = o.borderColor.flatMap { Self.parseHex($0) }
        let customBorder2 = o.borderColor2.flatMap { Self.parseHex($0) }
        let customGlow = o.glowColor.flatMap { Self.parseHex($0) }
        let customColor1 = o.neonColor.flatMap { Self.parseHex($0) }
        let customColor2 = o.neonColor2.flatMap { Self.parseHex($0) }

        // Convert Double? overrides to CGFloat
        let roundnessCGFloat = o.roundness.map { CGFloat($0) }
        let borderWidthCGFloat = o.borderWidth.map { CGFloat($0) }
        let borderOpacityCGFloat = o.borderOpacity.map { CGFloat($0) }
        let fillOpacityCGFloat = o.fillOpacity.map { CGFloat($0) }
        let glowOpacityCGFloat = o.glowOpacity.map { CGFloat($0) }
        let shadowOpacityCGFloat = o.shadowOpacity.map { CGFloat($0) }
        let shadowRadiusCGFloat = o.shadowRadius.map { CGFloat($0) }

        return AppearanceConfig(
            renderingStyle: renderingStyle,
            roundness: roundnessCGFloat ?? roundness,
            borderWidth: borderWidthCGFloat ?? borderWidth,
            borderTopOpacity: borderOpacityCGFloat.map { $0 * 0.375 } ?? borderTopOpacity,
            borderMidOpacity: borderOpacityCGFloat.map { $0 * 0.375 } ?? borderMidOpacity,
            borderBottomOpacity: borderOpacityCGFloat.map { $0 * 0.2 } ?? borderBottomOpacity,
            fillOpacity: fillOpacityCGFloat ?? fillOpacity,
            glowOpacity: glowOpacityCGFloat ?? glowOpacity,
            glowRadius: glowRadius,
            shadowOpacity: shadowOpacityCGFloat ?? shadowOpacity,
            shadowRadius: shadowRadiusCGFloat ?? shadowRadius,
            shadowY: shadowY,
            blurMaterial: blurMaterial,
            popupDarkTint: popupDarkTint,
            popupRoundness: popupRoundness,
            foregroundColor: customForeground ?? foregroundColor,
            accentColor: customAccent ?? customColor1 ?? accentColor,
            borderColor: customBorder ?? customColor1 ?? borderColor,
            borderColor2: customBorder2 ?? customColor2 ?? borderColor2,
            widgetBackgroundColor: customWidgetBg ?? widgetBackgroundColor,
            glowColor: customGlow ?? customColor1 ?? glowColor,
            barFont: FontConfig(
                fontName: o.barFontName.flatMap { $0.isEmpty ? nil : $0 } ?? barFont.fontName,
                fontSize: o.barFontSize.map { CGFloat($0) } ?? barFont.fontSize,
                weight: o.barFontWeight.map { Font.Weight.fromInt($0) ?? .medium } ?? barFont.weight
            ),
            widgetFont: FontConfig(
                fontName: o.widgetFontName.flatMap { $0.isEmpty ? nil : $0 } ?? widgetFont.fontName,
                fontSize: o.widgetFontSize.map { CGFloat($0) } ?? widgetFont.fontSize,
                weight: o.widgetFontWeight.map { Font.Weight.fromInt($0) ?? .medium } ?? widgetFont.weight
            ),
            useSingleFont: o.useSingleFont ?? useSingleFont
        )
    }

    func applyingPywal(_ pywal: PywalColors) -> AppearanceConfig {
        return AppearanceConfig(
            renderingStyle: renderingStyle,
            roundness: roundness,
            borderWidth: borderWidth,
            borderTopOpacity: borderTopOpacity,
            borderMidOpacity: borderMidOpacity,
            borderBottomOpacity: borderBottomOpacity,
            fillOpacity: fillOpacity,
            glowOpacity: glowOpacity,
            glowRadius: glowRadius,
            shadowOpacity: shadowOpacity,
            shadowRadius: shadowRadius,
            shadowY: shadowY,
            blurMaterial: blurMaterial,
            popupDarkTint: popupDarkTint,
            popupRoundness: popupRoundness,
            foregroundColor: pywal.colors[15],
            accentColor: pywal.colors[4],
            borderColor: pywal.colors[4],
            borderColor2: pywal.colors[5],
            widgetBackgroundColor: pywal.colors[0],
            glowColor: pywal.colors[4],
            barFont: barFont,
            widgetFont: widgetFont,
            useSingleFont: useSingleFont
        )
    }

    // MARK: - Hex parsing

    static func parseHex(_ hex: String) -> Color? {
        let h = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard h.count == 6 else { return nil }
        let scanner = Scanner(string: h)
        var rgb: UInt64 = 0
        guard scanner.scanHexInt64(&rgb) else { return nil }
        return Color(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}

/// Decodable user overrides from `[appearance]` in TOML.
/// All fields optional — only specified values override the preset.
struct AppearanceOverrides: Decodable {
    let roundness: Double?
    let borderWidth: Double?
    let borderOpacity: Double?
    let fillOpacity: Double?
    let glowOpacity: Double?
    let shadowOpacity: Double?
    let shadowRadius: Double?
    let foregroundColor: String?
    let accentColor: String?
    let widgetBackgroundColor: String?
    let borderColor: String?
    let borderColor2: String?
    let glowColor: String?
    let neonColor: String?
    let neonColor2: String?
    
    // Typography
    let barFontName: String?
    let barFontSize: Double?
    let barFontWeight: Int?
    let widgetFontName: String?
    let widgetFontSize: Double?
    let widgetFontWeight: Int?
    let useSingleFont: Bool?

    enum CodingKeys: String, CodingKey {
        case roundness
        case borderWidth = "border-width"
        case borderOpacity = "border-opacity"
        case fillOpacity = "fill-opacity"
        case glowOpacity = "glow-opacity"
        case shadowOpacity = "shadow-opacity"
        case shadowRadius = "shadow-radius"
        case foregroundColor = "foreground-color"
        case accentColor = "accent-color"
        case widgetBackgroundColor = "widget-background-color"
        case borderColor = "border-color"
        case borderColor2 = "border-color2"
        case glowColor = "glow-color"
        case neonColor = "neon-color"
        case neonColor2 = "neon-color2"
        
        // Typography
        case barFontName = "bar-font-name"
        case barFontSize = "bar-font-size"
        case barFontWeight = "bar-font-weight"
        case widgetFontName = "widget-font-name"
        case widgetFontSize = "widget-font-size"
        case widgetFontWeight = "widget-font-weight"
        case useSingleFont = "use-single-font"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Helper to decode numeric values that may be Int or Double
        func decodeNumber(for key: CodingKeys) throws -> Double? {
            if container.contains(key) {
                if let doubleVal = try? container.decode(Double.self, forKey: key) {
                    return doubleVal
                }
                if let intVal = try? container.decode(Int.self, forKey: key) {
                    return Double(intVal)
                }
            }
            return nil
        }
        
        // Helper to decode font weight from string or int
        func decodeFontWeight(for key: CodingKeys) throws -> Int? {
            guard container.contains(key) else { return nil }
            if let intVal = try? container.decode(Int.self, forKey: key) {
                return intVal
            }
            if let strVal = try? container.decode(String.self, forKey: key) {
                // Map common weight names to Int values
                switch strVal.lowercased() {
                case "thin": return 0
                case "ultraLight": return 2
                case "light": return 3
                case "regular": return 4
                case "medium": return 5
                case "semibold": return 6
                case "bold": return 7
                case "heavy": return 8
                case "black": return 9
                default: return nil
                }
            }
            return nil
        }

        roundness = try container.decodeIfPresent(Double.self, forKey: .roundness)
        borderWidth = try container.decodeIfPresent(Double.self, forKey: .borderWidth)
        borderOpacity = try decodeNumber(for: .borderOpacity)
        fillOpacity = try decodeNumber(for: .fillOpacity)
        glowOpacity = try decodeNumber(for: .glowOpacity)
        shadowOpacity = try decodeNumber(for: .shadowOpacity)
        shadowRadius = try decodeNumber(for: .shadowRadius)
        foregroundColor = try container.decodeIfPresent(String.self, forKey: .foregroundColor)
        accentColor = try container.decodeIfPresent(String.self, forKey: .accentColor)
        widgetBackgroundColor = try container.decodeIfPresent(String.self, forKey: .widgetBackgroundColor)
        borderColor = try container.decodeIfPresent(String.self, forKey: .borderColor)
        borderColor2 = try container.decodeIfPresent(String.self, forKey: .borderColor2)
        glowColor = try container.decodeIfPresent(String.self, forKey: .glowColor)
        neonColor = try container.decodeIfPresent(String.self, forKey: .neonColor)
        neonColor2 = try container.decodeIfPresent(String.self, forKey: .neonColor2)
        
        // Typography
        barFontName = try container.decodeIfPresent(String.self, forKey: .barFontName)
        barFontSize = try container.decodeIfPresent(Double.self, forKey: .barFontSize)
        barFontWeight = try decodeFontWeight(for: .barFontWeight)
        widgetFontName = try container.decodeIfPresent(String.self, forKey: .widgetFontName)
        widgetFontSize = try container.decodeIfPresent(Double.self, forKey: .widgetFontSize)
        widgetFontWeight = try decodeFontWeight(for: .widgetFontWeight)
        useSingleFont = try container.decodeIfPresent(Bool.self, forKey: .useSingleFont)
    }
}

// MARK: - Font.Weight extension

extension Font.Weight {
    /// Convert from Int (0-9) to Font.Weight
    static func fromInt(_ value: Int) -> Font.Weight? {
        switch value {
        case 0: return .thin
        case 1: return .ultraLight
        case 2: return .light
        case 3: return .regular
        case 4: return .medium
        case 5: return .semibold
        case 6: return .bold
        case 7: return .heavy
        case 8: return .black
        default: return nil
        }
    }
    
    /// Convert to Int (0-9)
    func toInt() -> Int {
        switch self {
        case .thin: return 0
        case .ultraLight: return 1
        case .light: return 2
        case .regular: return 3
        case .medium: return 4
        case .semibold: return 5
        case .bold: return 6
        case .heavy: return 7
        case .black: return 8
        default: return 4 // regular
        }
    }
}
