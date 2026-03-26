import SwiftUI

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
            glowColor: customGlow ?? customColor1 ?? glowColor
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
            glowColor: pywal.colors[4]
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
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Helper to decode numeric values that may be Int or Double
        func decodeNumber(for key: CodingKeys) throws Double? {
            if container.contains(key) {
                if let doubleVal = try? container.decode(Double.self, forKey: key) {
                    return doubleVal
                }
                if let intVal = try? container.decode(Int.self, forKey: key) {
                    return Double(intVal)
                }
                return nil // type mismatch, will be ignored
            }
            return nil
        }

        roundness = try decodeNumber(for: .roundness)
        borderWidth = try decodeNumber(for: .borderWidth)
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
    }
}
