import AppKit
import SwiftUI

/// A single marker syntax is shared by the native and command formatters.
/// Markers are atomic when labels are measured or truncated.
enum GlanceInlineIcons {
    private static let pattern = try? NSRegularExpression(pattern: "\\{\\{glance-icon:([^}]+)\\}\\}")
    private static let images: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 128
        return cache
    }()
    private static let paletteLock = NSLock()
    private static var cachedPalette: [Color]?
    private static var cachedPaletteHexes: [String] = []

    private static func paletteHexes(_ palette: [Color]) -> [String] {
        paletteLock.lock()
        defer { paletteLock.unlock() }
        if cachedPalette == palette { return cachedPaletteHexes }
        let hexes = palette.map { color -> String in
            let rgb = NSColor(color).usingColorSpace(.sRGB) ?? .white
            return String(format: "#%02X%02X%02X", Int(rgb.redComponent * 255), Int(rgb.greenComponent * 255), Int(rgb.blueComponent * 255))
        }
        cachedPalette = palette
        cachedPaletteHexes = hexes
        return hexes
    }

    /// Small geometric launcher used by the rail; keeps its preview and bar identical.
    static func image(_ name: String, size: CGFloat) -> NSImage? {
        let key = "\(name)|\(Double(size).bitPattern)" as NSString
        if let cached = images.object(forKey: key) { return cached }
        if name == "glance.pacman" {
            let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
                let path = NSBezierPath()
                let center = NSPoint(x: rect.midX, y: rect.midY)
                path.move(to: center)
                path.appendArc(withCenter: center, radius: size * 0.46, startAngle: 42, endAngle: 318, clockwise: false)
                path.close()
                path.appendOval(in: NSRect(x: size * 0.49, y: size * 0.64, width: size * 0.09, height: size * 0.09))
                path.windingRule = .evenOdd
                NSColor.black.setFill(); path.fill()
                return true
            }
            image.isTemplate = true
            images.setObject(image, forKey: key)
            return image
        }
        guard let source = NSImage(systemSymbolName: name, accessibilityDescription: nil) else { return nil }
        let result = source.withSymbolConfiguration(.init(pointSize: size, weight: .regular)) ?? source
        images.setObject(result, forKey: key)
        return result
    }

    static func resolve(_ values: ConfigData, palette: [Color] = []) -> ConfigData {
        var result = values
        if !palette.isEmpty {
            let hasPaletteMarkers = values.values.contains { value in
                guard let text = value.stringValue else { return false }
                return text.contains("pywal:") || text.contains("pywal-index:")
            }
            // Convert palette colors only when a value can use them. The one
            // entry cache is keyed by Color equality and remains bounded.
            let hexes = hasPaletteMarkers ? paletteHexes(palette) : []
            for (key, value) in values {
                guard var text = value.stringValue else { continue }
                if !hexes.isEmpty && (text.contains("pywal:") || text.contains("pywal-index:")) {
                    for index in hexes.indices.reversed() {
                        let hex = hexes[index]
                        text = text.replacingOccurrences(of: "pywal:\(index)", with: hex).replacingOccurrences(of: "pywal-index:\(index)", with: hex)
                    }
                }
                result[key] = .string(text)
            }
        }
        for (key, value) in values where key.hasPrefix("native-symbol-") {
            let component = String(key.dropFirst("native-symbol-".count))
            guard let symbol = value.stringValue, !symbol.isEmpty else { continue }
            result[component] = .string("{{glance-icon:" + symbol + "}}" + (component == "format-prefix" ? "%{O\(values["native-icon-spacing"]?.doubleValue ?? 6)px}" : ""))
        }
        return result
    }

    static func units(_ text: String) -> [String] {
        guard let regex = pattern else { return text.map(String.init) }
        var units: [String] = []
        var cursor = text.startIndex
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let range = Range(match.range, in: text) else { continue }
            units += text[cursor..<range.lowerBound].map(String.init)
            units.append(String(text[range])); cursor = range.upperBound
        }
        units += text[cursor...].map(String.init)
        return units
    }

    static func attributed(_ text: String, attributes: [NSAttributedString.Key: Any]) -> NSMutableAttributedString {
        let result = NSMutableAttributedString(string: text, attributes: attributes)
        guard let regex = pattern else { return result }
        let font = attributes[.font] as? NSFont ?? .systemFont(ofSize: 14)
        let color = attributes[.foregroundColor] as? NSColor ?? .labelColor
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
            guard let symbolRange = Range(match.range(at: 1), in: text),
                  let symbol = image(String(text[symbolRange]), size: font.pointSize) else { continue }
            let image = NSImage(size: NSSize(width: font.pointSize, height: font.pointSize), flipped: false) { rect in
                symbol.draw(in: rect)
                color.setFill(); rect.fill(using: .sourceAtop)
                return true
            }
            let attachment = NSTextAttachment()
            attachment.image = image
            attachment.bounds = NSRect(x: 0, y: font.descender, width: font.pointSize, height: font.pointSize)
            result.replaceCharacters(in: match.range, with: NSAttributedString(attachment: attachment))
        }
        return result
    }
}
