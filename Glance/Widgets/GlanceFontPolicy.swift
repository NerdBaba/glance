import AppKit
import SwiftUI

/// Global text settings apply across imported formats without replacing their
/// private-use icon fonts or font-drawn transitions.
enum GlanceFontPolicy {
    static func usesGlobal(_ config: ConfigData, appearance: AppearanceConfig) -> Bool {
        guard !GlanceTransitionWidget.isDecoration(config) else { return false }
        return config["font-use-global"]?.boolValue ?? appearance.overrideModuleFonts
    }

    static func font(_ appearance: AppearanceConfig) -> FontConfig {
        appearance.useSingleFont ? appearance.barFont : appearance.widgetFont
    }

    static func nsFont(_ appearance: AppearanceConfig) -> NSFont {
        let config = font(appearance)
        let weights: [NSFont.Weight] = [.thin, .ultraLight, .light, .regular, .medium, .semibold, .bold, .heavy, .black]
        let weight = weights[min(max(config.weight.toInt(), 0), 8)]
        guard let name = config.fontName, let base = NSFont(name: name, size: config.fontSize) else {
            return .systemFont(ofSize: config.fontSize, weight: weight)
        }
        let descriptor = base.fontDescriptor.addingAttributes([.traits: [NSFontDescriptor.TraitKey.weight: weight.rawValue]])
        return NSFont(descriptor: descriptor, size: config.fontSize) ?? base
    }

    static func isIcon(_ character: Character) -> Bool {
        character.unicodeScalars.contains { scalar in
            (0xE000...0xF8FF).contains(scalar.value) || (0xF0000...0xFFFFD).contains(scalar.value) || (0x100000...0x10FFFD).contains(scalar.value)
        }
    }

    static func text(_ value: String, glyphFont: Font) -> Text {
        var result = Text("")
        var run = ""
        var icon = false
        for character in value {
            let next = isIcon(character)
            if !run.isEmpty && next != icon {
                result = result + (icon ? Text(run).font(glyphFont) : Text(run))
                run = ""
            }
            icon = next; run.append(character)
        }
        return result + (icon ? Text(run).font(glyphFont) : Text(run))
    }

    static func applyTextFont(_ font: NSFont, to value: NSMutableAttributedString) {
        var position = 0
        for character in value.string {
            let length = String(character).utf16.count
            if !isIcon(character), value.attribute(.attachment, at: position, effectiveRange: nil) == nil {
                value.addAttribute(.font, value: font, range: NSRange(location: position, length: length))
            }
            position += length
        }
    }
}
