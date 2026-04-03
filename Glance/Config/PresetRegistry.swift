import AppKit
import SwiftUI

/// Built-in visual presets. Each preset is a complete visual identity —
/// rendering style, colors, and shape parameters.
enum Preset: String, CaseIterable {
    case liquidGlass  = "liquid-glass"
    case frosted      = "frosted"
    case flatDark     = "flat-dark"
    case minimal      = "minimal"
    case neon         = "neon"
    case tokyoNight   = "tokyo-night"
    case dracula      = "dracula"
    case gruvbox      = "gruvbox"
    case nord         = "nord"
    case catppuccin   = "catppuccin"
    case solarized    = "solarized"

    // MARK: - Hex helper

    private static func hex(_ hex: String) -> Color {
        let h = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        let scanner = Scanner(string: h)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        return Color(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }

    /// Full appearance defaults for this preset.
    var defaults: AppearanceConfig {
        switch self {

        // ── Glass presets ─────────────────────────────────────────

        case .liquidGlass:
            return AppearanceConfig(
                renderingStyle: .glass,
                roundness: 50,
                borderWidth: 1.0,
                borderTopOpacity: 0.40,
                borderMidOpacity: 0.15,
                borderBottomOpacity: 0.08,
                fillOpacity: 0.04,
                glowOpacity: 0.05,
                glowRadius: 2,
                shadowOpacity: 0.08,
                shadowRadius: 4,
                shadowY: 2,
                blurMaterial: .popover,
                popupDarkTint: 0.25,
                popupRoundness: 40,
                foregroundColor: .white,
                accentColor: .white,
                borderColor: .white,
                borderColor2: nil,
                widgetBackgroundColor: .white,
                glowColor: .white,
                barFont: FontConfig(fontName: nil, fontSize: 13, weight: .medium),
                widgetFont: FontConfig(fontName: nil, fontSize: 13, weight: .medium),
                useSingleFont: true
            )

        case .frosted:
            return AppearanceConfig(
                renderingStyle: .glass,
                roundness: 14,
                borderWidth: 0.5,
                borderTopOpacity: 0.18,
                borderMidOpacity: 0.10,
                borderBottomOpacity: 0.05,
                fillOpacity: 0.25,
                glowOpacity: 0,
                glowRadius: 0,
                shadowOpacity: 0.06,
                shadowRadius: 3,
                shadowY: 1,
                blurMaterial: .hudWindow,
                popupDarkTint: 0.45,
                popupRoundness: 16,
                foregroundColor: .white,
                accentColor: .white.opacity(0.9),
                borderColor: .white,
                borderColor2: nil,
                widgetBackgroundColor: .white,
                glowColor: .clear,
                barFont: FontConfig(fontName: nil, fontSize: 13, weight: .medium),
                widgetFont: FontConfig(fontName: nil, fontSize: 13, weight: .medium),
                useSingleFont: true
            )

        // ── Flat presets ──────────────────────────────────────────

        case .flatDark:
            return AppearanceConfig(
                renderingStyle: .solid,
                roundness: 8,
                borderWidth: 0.5,
                borderTopOpacity: 0.12,
                borderMidOpacity: 0.12,
                borderBottomOpacity: 0.12,
                fillOpacity: 0.85,
                glowOpacity: 0,
                glowRadius: 0,
                shadowOpacity: 0,
                shadowRadius: 0,
                shadowY: 0,
                blurMaterial: .popover,
                popupDarkTint: 0,
                popupRoundness: 12,
                foregroundColor: Self.hex("#e0e0e0"),
                accentColor: .white,
                borderColor: Self.hex("#333333"),
                borderColor2: nil,
                widgetBackgroundColor: Self.hex("#1c1c1c"),
                glowColor: .clear,
                barFont: FontConfig(fontName: nil, fontSize: 13, weight: .medium),
                widgetFont: FontConfig(fontName: nil, fontSize: 13, weight: .medium),
                useSingleFont: true
            )

        case .minimal:
            return AppearanceConfig(
                renderingStyle: .minimal,
                roundness: 0,
                borderWidth: 0,
                borderTopOpacity: 0,
                borderMidOpacity: 0,
                borderBottomOpacity: 0,
                fillOpacity: 0,
                glowOpacity: 0,
                glowRadius: 0,
                shadowOpacity: 0,
                shadowRadius: 0,
                shadowY: 0,
                blurMaterial: .popover,
                popupDarkTint: 0.70,
                popupRoundness: 12,
                foregroundColor: .white,
                accentColor: .white,
                borderColor: .clear,
                borderColor2: nil,
                widgetBackgroundColor: .clear,
                glowColor: .clear,
                barFont: FontConfig(fontName: nil, fontSize: 13, weight: .medium),
                widgetFont: FontConfig(fontName: nil, fontSize: 13, weight: .medium),
                useSingleFont: true
            )

        // ── Neon — cyberpunk glow with pink→cyan gradient ────────

        case .neon:
            return AppearanceConfig(
                renderingStyle: .solid,
                roundness: 20,
                borderWidth: 1.5,
                borderTopOpacity: 0.85,
                borderMidOpacity: 0.55,
                borderBottomOpacity: 0.35,
                fillOpacity: 0.92,
                glowOpacity: 0.35,
                glowRadius: 8,
                shadowOpacity: 0.25,
                shadowRadius: 12,
                shadowY: 0,
                blurMaterial: .popover,
                popupDarkTint: 0,
                popupRoundness: 24,
                foregroundColor: Self.hex("#f0f0f0"),
                accentColor: Self.hex("#ff44cc"),
                borderColor: Self.hex("#ff44cc"),
                borderColor2: Self.hex("#00e5ff"),
                widgetBackgroundColor: Self.hex("#0a0a0a"),
                glowColor: Self.hex("#ff44cc"),
                barFont: FontConfig(fontName: nil, fontSize: 13, weight: .medium),
                widgetFont: FontConfig(fontName: nil, fontSize: 13, weight: .medium),
                useSingleFont: true
            )

        // ── Tokyo Night — dreamy night atmosphere ────────────────
        // Deep indigo bg, soft lavender text, blue accent with violet undertones.
        // Subtle blue glow evokes the neon-lit night city aesthetic.

        case .tokyoNight:
            return AppearanceConfig(
                renderingStyle: .solid,
                roundness: 12,
                borderWidth: 1.0,
                borderTopOpacity: 0.30,
                borderMidOpacity: 0.15,
                borderBottomOpacity: 0.08,
                fillOpacity: 0.92,
                glowOpacity: 0.12,
                glowRadius: 4,
                shadowOpacity: 0.10,
                shadowRadius: 6,
                shadowY: 2,
                blurMaterial: .popover,
                popupDarkTint: 0,
                popupRoundness: 14,
                foregroundColor: Self.hex("#a9b1d6"),   // Storm — fg
                accentColor: Self.hex("#7aa2f7"),       // Blue
                borderColor: Self.hex("#7aa2f7"),       // Blue border top
                borderColor2: Self.hex("#9d7cd8"),      // Purple border bottom
                widgetBackgroundColor: Self.hex("#1a1b26"), // Night bg
                glowColor: Self.hex("#7aa2f7"),          // Blue glow
                barFont: FontConfig(fontName: nil, fontSize: 13, weight: .medium),
                widgetFont: FontConfig(fontName: nil, fontSize: 13, weight: .medium),
                useSingleFont: true
            )

        // ── Dracula — bold, contrasty, purple-pink on dark ───────
        // Purple primary, pink secondary. Gradient border purple→pink.
        // Slightly more visible borders than average — Dracula is bold.

        case .dracula:
            return AppearanceConfig(
                renderingStyle: .solid,
                roundness: 10,
                borderWidth: 1.0,
                borderTopOpacity: 0.35,
                borderMidOpacity: 0.20,
                borderBottomOpacity: 0.10,
                fillOpacity: 0.92,
                glowOpacity: 0.10,
                glowRadius: 4,
                shadowOpacity: 0.10,
                shadowRadius: 5,
                shadowY: 2,
                blurMaterial: .popover,
                popupDarkTint: 0,
                popupRoundness: 14,
                foregroundColor: Self.hex("#f8f8f2"),   // Foreground
                accentColor: Self.hex("#bd93f9"),       // Purple
                borderColor: Self.hex("#bd93f9"),       // Purple border
                borderColor2: Self.hex("#ff79c6"),      // Pink gradient end
                widgetBackgroundColor: Self.hex("#282a36"), // Background
                glowColor: Self.hex("#bd93f9"),          // Purple glow
                barFont: FontConfig(fontName: nil, fontSize: 13, weight: .medium),
                widgetFont: FontConfig(fontName: nil, fontSize: 13, weight: .medium),
                useSingleFont: true
            )

        // ── Gruvbox — warm retro, earthy orange on dark brown ────
        // Warm, textured feel. Orange accent, yellow secondary.
        // Slightly rounded, thicker borders for that retro CRT quality.

        case .gruvbox:
            return AppearanceConfig(
                renderingStyle: .solid,
                roundness: 10,
                borderWidth: 1.0,
                borderTopOpacity: 0.28,
                borderMidOpacity: 0.18,
                borderBottomOpacity: 0.10,
                fillOpacity: 0.93,
                glowOpacity: 0.08,
                glowRadius: 3,
                shadowOpacity: 0.08,
                shadowRadius: 4,
                shadowY: 2,
                blurMaterial: .popover,
                popupDarkTint: 0,
                popupRoundness: 12,
                foregroundColor: Self.hex("#ebdbb2"),   // fg
                accentColor: Self.hex("#fe8019"),       // Orange
                borderColor: Self.hex("#fe8019"),       // Orange border
                borderColor2: Self.hex("#fabd2f"),      // Yellow gradient end
                widgetBackgroundColor: Self.hex("#282828"), // bg0
                glowColor: Self.hex("#fe8019"),          // Warm orange glow
                barFont: FontConfig(fontName: nil, fontSize: 13, weight: .medium),
                widgetFont: FontConfig(fontName: nil, fontSize: 13, weight: .medium),
                useSingleFont: true
            )

        // ── Nord — arctic, clean, precise ────────────────────────
        // Cool blues on deep polar night. Crisp borders, no glow —
        // Nord is about clarity and restraint, like fresh arctic air.

        case .nord:
            return AppearanceConfig(
                renderingStyle: .solid,
                roundness: 8,
                borderWidth: 0.5,
                borderTopOpacity: 0.25,
                borderMidOpacity: 0.15,
                borderBottomOpacity: 0.08,
                fillOpacity: 0.92,
                glowOpacity: 0,
                glowRadius: 0,
                shadowOpacity: 0.06,
                shadowRadius: 3,
                shadowY: 2,
                blurMaterial: .popover,
                popupDarkTint: 0,
                popupRoundness: 10,
                foregroundColor: Self.hex("#d8dee9"),   // Snow Storm
                accentColor: Self.hex("#88c0d0"),       // Frost (cyan)
                borderColor: Self.hex("#434c5e"),       // Polar Night 3
                borderColor2: nil,                      // No gradient — clean
                widgetBackgroundColor: Self.hex("#2e3440"), // Polar Night 1
                glowColor: .clear,                       // No glow — crisp
                barFont: FontConfig(fontName: nil, fontSize: 13, weight: .medium),
                widgetFont: FontConfig(fontName: nil, fontSize: 13, weight: .medium),
                useSingleFont: true
            )

        // ── Catppuccin Mocha — soft, pastel, cozy ────────────────
        // Lavender/mauve on warm dark base. More rounded for softness.
        // Gentle mauve glow, wider popup roundness — everything is smooth.

        case .catppuccin:
            return AppearanceConfig(
                renderingStyle: .solid,
                roundness: 16,
                borderWidth: 0.8,
                borderTopOpacity: 0.25,
                borderMidOpacity: 0.15,
                borderBottomOpacity: 0.08,
                fillOpacity: 0.92,
                glowOpacity: 0.10,
                glowRadius: 4,
                shadowOpacity: 0.08,
                shadowRadius: 5,
                shadowY: 2,
                blurMaterial: .popover,
                popupDarkTint: 0,
                popupRoundness: 18,
                foregroundColor: Self.hex("#cdd6f4"),   // Text
                accentColor: Self.hex("#cba6f7"),       // Mauve
                borderColor: Self.hex("#cba6f7"),       // Mauve border
                borderColor2: Self.hex("#89b4fa"),      // Blue gradient end
                widgetBackgroundColor: Self.hex("#1e1e2e"), // Base
                glowColor: Self.hex("#cba6f7"),          // Soft mauve glow
                barFont: FontConfig(fontName: nil, fontSize: 13, weight: .medium),
                widgetFont: FontConfig(fontName: nil, fontSize: 13, weight: .medium),
                useSingleFont: true
            )

        // ── Solarized Dark — precise, scientific, timeless ───────
        // Ethan Schoonover's canonical palette. Teal-black base, precise borders.
        // No glow, no gradient — Solarized is functional elegance.
        // Slightly squared-off feel (low roundness), understated border.

        case .solarized:
            return AppearanceConfig(
                renderingStyle: .solid,
                roundness: 6,
                borderWidth: 0.5,
                borderTopOpacity: 0.22,
                borderMidOpacity: 0.14,
                borderBottomOpacity: 0.08,
                fillOpacity: 0.93,
                glowOpacity: 0,
                glowRadius: 0,
                shadowOpacity: 0.06,
                shadowRadius: 3,
                shadowY: 2,
                blurMaterial: .popover,
                popupDarkTint: 0,
                popupRoundness: 10,
                foregroundColor: Self.hex("#839496"),   // base0
                accentColor: Self.hex("#268bd2"),       // blue
                borderColor: Self.hex("#073642"),       // base02
                borderColor2: nil,                      // No gradient — clean
                widgetBackgroundColor: Self.hex("#002b36"), // base03
                glowColor: .clear,                       // No glow — understated
                barFont: FontConfig(fontName: nil, fontSize: 13, weight: .medium),
                widgetFont: FontConfig(fontName: nil, fontSize: 13, weight: .medium),
                useSingleFont: true
            )
        }
    }

    /// Maps legacy `style = "..."` values to a preset.
    static func fromLegacyStyle(_ style: String) -> Preset {
        switch style {
        case "glass": return .liquidGlass
        case "solid": return .flatDark
        case "minimal": return .minimal
        default: return .liquidGlass
        }
    }
}
