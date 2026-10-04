import AppKit
import Foundation
import SwiftUI

/// Configuration understood by Glance's Polybar custom/script renderer.
/// Keys intentionally match Polybar's option names so an INI importer can map
/// them without inventing an intermediate vocabulary.
struct PolybarScriptOptions {
    let values: ConfigData

    var command: String { string("exec") ?? string("command") ?? "" }
    var execIf: String? { string("exec-if") }
    var tail: Bool { bool("tail") ?? false }
    var interval: TimeInterval { max(0, double("interval") ?? (tail ? 0 : 5)) }
    var intervalFail: TimeInterval { max(1, double("interval-fail") ?? max(interval, 1)) }
    var intervalIf: TimeInterval { max(1, double("interval-if") ?? max(interval, 1)) }
    var timeout: TimeInterval { max(1, double("timeout") ?? 5) }

    var environment: [String: String] {
        var result: [String: String] = [:]
        for (key, value) in values where key.hasPrefix("env-") {
            if let string = value.stringValue { result[String(key.dropFirst(4))] = string }
        }
        return result
    }

    func string(_ key: String) -> String? { values[key]?.stringValue }
    func bool(_ key: String) -> Bool? { values[key]?.boolValue }
    func double(_ key: String) -> Double? { values[key]?.doubleValue }
    func integer(_ key: String) -> Int? { values[key]?.intValue }

    var animationFrameDurations: [TimeInterval] {
        let names = Set(values.keys.compactMap { key -> String? in
            guard key.hasPrefix("animation-") else { return nil }
            let remainder = String(key.dropFirst("animation-".count))
            if Int(remainder) != nil { return "" }
            guard let separator = remainder.lastIndex(of: "-"),
                  Int(remainder[remainder.index(after: separator)...]) != nil else { return nil }
            return String(remainder[..<separator])
        })
        return names.map { name in
            let prefix = name.isEmpty ? "animation" : "animation-\(name)"
            return max(0.001, (double("\(prefix)-framerate") ?? 1_000) / 1_000)
        }
    }
}

struct PolybarScriptTextStyle: Equatable {
    var foreground: NSColor?
    var background: NSColor?
    var underline: NSColor?
    var overline: NSColor?
    var font: NSFont?
}

enum PolybarScriptPiece {
    case text(String, PolybarScriptTextStyle, [Int: String])
    case offset(CGFloat)
}

/// Expands custom/script labels, ramps, progress bars, and lemonbar markup.
/// The component names follow Polybar's `<label>`, `<ramp-NAME>`, and
/// `<bar-NAME>` formatting syntax.
enum PolybarScriptRenderer {
    private static let componentRegex = try? NSRegularExpression(pattern: "<([A-Za-z][A-Za-z0-9_-]*)>")
    private static let tokenRegex = try? NSRegularExpression(
        pattern: "%([A-Za-z][A-Za-z0-9_-]*)(?::(-?[0-9]*))?(?::(-?[0-9]*))?(?::([^%]*))?%"
    )
    private static let numberRegex = try? NSRegularExpression(pattern: "[-+]?[0-9]*\\.?[0-9]+")
    // NSCache is thread safe and bounded; edited user patterns cannot accumulate forever.
    private static let valueRegexes: NSCache<NSString, NSRegularExpression> = {
        let cache = NSCache<NSString, NSRegularExpression>()
        cache.countLimit = 64
        return cache
    }()

    private static func valueRegex(_ pattern: String) -> NSRegularExpression? {
        let key = pattern as NSString
        if let cached = valueRegexes.object(forKey: key) { return cached }
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        valueRegexes.setObject(regex, forKey: key)
        return regex
    }

    static func render(
        output: String,
        config: ConfigData,
        actions: [Int: String],
        counter: Int,
        pid: Int32?,
        failed: Bool,
        animationTime: TimeInterval = 0
    ) -> [PolybarScriptPiece] {
        let options = PolybarScriptOptions(values: config)
        let rawValue = extractValue(from: output, options: options)
        let minValue = options.double("value-min") ?? 0
        let maxValue = options.double("value-max") ?? 100
        let percentage = maxValue > minValue
            ? min(100, max(0, (rawValue - minValue) / (maxValue - minValue) * 100))
            : 0

        let format = (failed ? options.string("format-fail") : nil)
            ?? options.string("format")
            ?? "<label>"
        let stateName = failed ? "fail" : nil
        let prefix = options.string(stateName.map { "format-\($0)-prefix" } ?? "format-prefix") ?? ""
        let suffix = options.string(stateName.map { "format-\($0)-suffix" } ?? "format-suffix") ?? ""
        let label = options.string(failed ? "label-fail" : "label") ?? "%output%"
        var expanded = prefix + format + suffix

        expanded = replaceComponents(
            in: expanded,
            label: label,
            options: options,
            output: output,
            rawValue: rawValue,
            percentage: percentage,
            counter: counter,
            pid: pid,
            animationTime: animationTime
        )
        expanded = expandTokens(
            expanded,
            output: output,
            rawValue: rawValue,
            percentage: percentage,
            counter: counter,
            pid: pid
        )
        expanded = expandFormatStyle(expanded, options: options, stateName: stateName)

        let paddingKey = stateName.map { "format-\($0)-padding" } ?? "format-padding"
        if let padding = options.integer(paddingKey), padding > 0 {
            expanded = String(repeating: " ", count: min(padding, 128)) + expanded
                + String(repeating: " ", count: min(padding, 128))
        } else if let padding = options.string(paddingKey),
                  padding.hasSuffix("px") || padding.hasSuffix("pt") {
            expanded = "%{O\(padding)}" + expanded + "%{O\(padding)}"
        }
        let offsetKey = stateName.map { "format-\($0)-offset" } ?? "format-offset"
        if let offset = options.string(offsetKey) ?? options.integer(offsetKey).map(String.init) {
            expanded = "%{O\(offset)}" + expanded
        }

        return parseMarkup(expanded, actions: actions, options: options)
    }

    private static func replaceComponents(
        in format: String,
        label: String,
        options: PolybarScriptOptions,
        output: String,
        rawValue: Double,
        percentage: Double,
        counter: Int,
        pid: Int32?,
        animationTime: TimeInterval
    ) -> String {
        guard let regex = componentRegex else {
            return format
        }
        let nsFormat = format as NSString
        let matches = regex.matches(in: format, range: NSRange(location: 0, length: nsFormat.length))
        var result = format
        for match in matches.reversed() {
            guard match.numberOfRanges > 1 else { continue }
            let component = nsFormat.substring(with: match.range(at: 1))
            let replacement: String
            if component == "label" || component.hasPrefix("label-") {
                let componentLabel = component == "label"
                    ? label
                    : options.string(component) ?? label
                replacement = renderLabel(
                    componentLabel,
                    name: component,
                    options: options,
                    output: output,
                    rawValue: rawValue,
                    percentage: percentage,
                    counter: counter,
                    pid: pid
                )
            } else if component.hasPrefix("ramp-") {
                let name = String(component.dropFirst("ramp-".count))
                replacement = renderRamp(name: name, options: options, value: percentage)
            } else if component.hasPrefix("bar-") {
                let name = String(component.dropFirst("bar-".count))
                replacement = renderProgressBar(name: name, options: options, value: percentage)
            } else if component == "animation" {
                replacement = renderAnimation(name: "", options: options, elapsed: animationTime)
            } else if component.hasPrefix("animation-") {
                let name = String(component.dropFirst("animation-".count))
                replacement = renderAnimation(name: name, options: options, elapsed: animationTime)
            } else {
                continue
            }
            if let range = Range(match.range, in: result) {
                result.replaceSubrange(range, with: replacement)
            }
        }
        return result
    }

    private static func renderLabel(
        _ source: String,
        name: String,
        options: PolybarScriptOptions,
        output: String,
        rawValue: Double,
        percentage: Double,
        counter: Int,
        pid: Int32?
    ) -> String {
        var text = expandTokens(
            source,
            output: output,
            rawValue: rawValue,
            percentage: percentage,
            counter: counter,
            pid: pid
        )
        let prefix = name == "label" ? "label" : name
        let maxLength = options.integer("\(prefix)-maxlen")
            ?? (name == "label" ? options.integer("label-maxlen") : nil)
        if let maxLength, maxLength > 0, text.count > maxLength {
            let useEllipsis = options.bool("\(prefix)-ellipsis") ?? options.bool("label-ellipsis") ?? true
            let suffix = useEllipsis ? "…" : ""
            text = String(text.prefix(max(0, maxLength - suffix.count))) + suffix
        }
        let minimumLength = options.integer("\(prefix)-minlen")
            ?? (name == "label" ? options.integer("label-minlen") : nil)
        if let minimumLength, minimumLength > text.count {
            let padding = String(repeating: " ", count: minimumLength - text.count)
            switch options.string("\(prefix)-alignment") ?? options.string("label-alignment") ?? "left" {
            case "right": text = padding + text
            case "center":
                let leading = padding.count / 2
                text = String(repeating: " ", count: leading) + text
                    + String(repeating: " ", count: padding.count - leading)
            default: text += padding
            }
        }
        if let margin = options.integer("\(prefix)-margin"), margin > 0 {
            let spaces = String(repeating: " ", count: min(margin, 128))
            text = spaces + text + spaces
        }
        let styledText = styled(text, stylePrefix: prefix, basePrefix: "label", options: options)
        if let padding = options.integer("\(prefix)-padding"), padding > 0 {
            let spaces = String(repeating: " ", count: min(padding, 128))
            return spaces + styledText + spaces
        }
        return styledText
    }

    private static func expandTokens(
        _ text: String,
        output: String,
        rawValue: Double,
        percentage: Double,
        counter: Int,
        pid: Int32?
    ) -> String {
        let values = [
            "output": output.trimmingCharacters(in: .newlines),
            "value": formatNumber(rawValue),
            "percentage": String(Int(percentage.rounded())),
            "counter": String(counter),
            "pid": pid.map(String.init) ?? ""
        ]
        guard let regex = tokenRegex else { return text }
        let source = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: source.length))
        var result = text
        for match in matches.reversed() {
            guard match.numberOfRanges >= 2 else { continue }
            let name = source.substring(with: match.range(at: 1))
            guard var replacement = values[name] else { continue }
            let minWidth = match.range(at: 2).location == NSNotFound
                ? nil : Int(source.substring(with: match.range(at: 2)))
            let maxWidth = match.range(at: 3).location == NSNotFound
                ? nil : Int(source.substring(with: match.range(at: 3)))
            let suffix = match.range(at: 4).location == NSNotFound
                ? "" : source.substring(with: match.range(at: 4))

            if let maxWidth, maxWidth > 0, replacement.count > maxWidth {
                let visibleCount = max(0, maxWidth - suffix.count)
                replacement = String(replacement.prefix(visibleCount)) + suffix
            }
            if let minWidth {
                let width = abs(minWidth)
                if replacement.count < width {
                    let fill = name == "output" && source.substring(with: match.range(at: 2)).hasPrefix("0") ? "0" : " "
                    let padding = String(repeating: fill, count: width - replacement.count)
                    replacement = minWidth < 0 ? replacement + padding : padding + replacement
                }
            }
            if let range = Range(match.range, in: result) {
                result.replaceSubrange(range, with: replacement)
            }
        }
        return result
    }

    private static func extractValue(from output: String, options: PolybarScriptOptions) -> Double {
        if let configured = options.double("value") { return configured }
        let source = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if let pattern = options.string("value-regex"),
           let regex = valueRegex(pattern),
           let match = regex.firstMatch(in: source, range: NSRange(source.startIndex..., in: source)) {
            let range = match.numberOfRanges > 1 ? match.range(at: 1) : match.range(at: 0)
            if let swiftRange = Range(range, in: source),
               let number = Double(source[swiftRange].replacingOccurrences(of: "%", with: "")) {
                return number
            }
        }
        guard let regex = numberRegex else { return 0 }
        let range = NSRange(source.startIndex..., in: source)
        guard let match = regex.firstMatch(in: source, range: range),
              let swiftRange = Range(match.range, in: source) else { return 0 }
        return Double(source[swiftRange]) ?? 0
    }

    private static func renderRamp(name: String, options: PolybarScriptOptions, value: Double) -> String {
        let prefix = "ramp-\(name)-"
        var levels: [(index: Int, text: String, weight: Double, style: String)] = []
        for (key, item) in options.values {
            guard key.hasPrefix(prefix), let text = item.stringValue else { continue }
            let remainder = String(key.dropFirst(prefix.count))
            guard let index = Int(remainder) else { continue }
            let weight = max(0, options.double("\(prefix)\(index)-weight") ?? 1)
            levels.append((index, text, weight, "\(prefix)\(index)"))
        }
        levels.sort { $0.index < $1.index }
        guard !levels.isEmpty else { return "" }
        guard levels.count > 1 else {
            return styled(levels[0].text, stylePrefix: levels[0].style, basePrefix: "ramp-\(name)", options: options)
        }
        if value <= 0 {
            let edge = levels[0]
            return styled(edge.text, stylePrefix: edge.style, basePrefix: "ramp-\(name)", options: options)
        }
        if value >= 100 {
            let edge = levels[levels.count - 1]
            return styled(edge.text, stylePrefix: edge.style, basePrefix: "ramp-\(name)", options: options)
        }

        let interior = Array(levels.dropFirst().dropLast())
        guard !interior.isEmpty else {
            let edge = levels[0]
            return styled(edge.text, stylePrefix: edge.style, basePrefix: "ramp-\(name)", options: options)
        }
        let totalWeight = interior.reduce(0) { $0 + $1.weight }
        var cursor = 0.0
        let selected = interior.first { level in
            cursor += totalWeight > 0 ? level.weight / totalWeight * 100 : 0
            return value <= cursor
        } ?? interior.last!
        return styled(selected.text, stylePrefix: selected.style, basePrefix: "ramp-\(name)", options: options)
    }

    private static func renderAnimation(name: String, options: PolybarScriptOptions, elapsed: TimeInterval) -> String {
        let prefix = name.isEmpty ? "animation" : "animation-\(name)"
        var frames: [(index: Int, text: String)] = []
        for (key, item) in options.values {
            guard key.hasPrefix(prefix + "-"), let text = item.stringValue else { continue }
            let suffix = String(key.dropFirst((prefix + "-").count))
            guard let index = Int(suffix) else { continue }
            frames.append((index, text))
        }
        frames.sort { $0.index < $1.index }
        guard !frames.isEmpty else { return "" }

        let frameRateMilliseconds = options.double("\(prefix)-framerate") ?? 1_000
        let frameDuration = max(0.001, frameRateMilliseconds / 1_000)
        let step = Int(max(0, elapsed) / frameDuration)
        let frame = frames[step % frames.count]
        return styled(frame.text, stylePrefix: "\(prefix)-\(frame.index)", basePrefix: prefix, options: options)
    }

    private static func renderProgressBar(name: String, options: PolybarScriptOptions, value: Double) -> String {
        let prefix = "bar-\(name)"
        let width = min(256, max(1, options.integer("\(prefix)-width") ?? 10))
        let fill = options.string("\(prefix)-fill") ?? "━"
        let empty = options.string("\(prefix)-empty") ?? "━"
        let indicator = options.string("\(prefix)-indicator")
        let fraction = min(1, max(0, value / 100))
        let filled = min(width, max(0, Int((fraction * Double(width)).rounded(.down))))
        let gradient = options.bool("\(prefix)-gradient") ?? false
        let gradientColors = options.values.compactMap { key, value -> (Int, NSColor)? in
            let colorPrefix = "\(prefix)-foreground-"
            guard key.hasPrefix(colorPrefix), let index = Int(key.dropFirst(colorPrefix.count)),
                  let color = value.stringValue.flatMap(polybarColor) else { return nil }
            return (index, color)
        }.sorted { $0.0 < $1.0 }

        var filledParts: [String] = []
        for index in 0..<filled {
            var glyph = styled(
                fill,
                stylePrefix: "\(prefix)-fill",
                basePrefix: prefix,
                options: options,
                excludingFields: gradientColors.isEmpty ? [] : ["foreground"]
            )
            if !gradientColors.isEmpty {
                let location = gradient ? (width > 1 ? Double(index) / Double(width - 1) : 0) : fraction
                let color = interpolatedColor(at: location, colors: gradientColors)
                glyph = "%{F\(color.hexString)}\(glyph)%{F-}"
            }
            filledParts.append(glyph)
        }
        let emptyParts = (filled..<width).map { _ in
            styled(empty, stylePrefix: "\(prefix)-empty", basePrefix: prefix, options: options)
        }
        let indicatorPart = indicator.map {
            styled($0, stylePrefix: "\(prefix)-indicator", basePrefix: prefix, options: options)
        } ?? ""
        let barFormat = options.string("\(prefix)-format") ?? "%fill%%indicator%%empty%"
        return barFormat
            .replacingOccurrences(of: "%fill%", with: filledParts.joined())
            .replacingOccurrences(of: "%indicator%", with: indicatorPart)
            .replacingOccurrences(of: "%empty%", with: emptyParts.joined())
    }

    private static func styled(
        _ text: String,
        stylePrefix: String,
        basePrefix: String,
        options: PolybarScriptOptions,
        excludingFields: Set<String> = []
    ) -> String {
        var tags = ""
        let fields = ["foreground": "F", "background": "B", "underline": "u", "overline": "o", "font": "T"]
        for (field, tag) in fields {
            guard !excludingFields.contains(field) else { continue }
            let value = options.string("\(stylePrefix)-\(field)") ?? options.string("\(basePrefix)-\(field)")
            if let value, !value.isEmpty {
                if field == "font", let index = Int(value) {
                    tags += "%{T\(index)}"
                } else {
                    tags += "%{\(tag)\(value)}"
                }
            }
        }
        return tags + text + "%{F-}%{B-}%{u-}%{o-}%{T-}"
    }

    private static func expandFormatStyle(_ format: String, options: PolybarScriptOptions, stateName: String?) -> String {
        var result = format
        var opening = ""
        var closing = ""
        let fields = [("foreground", "F"), ("background", "B"), ("underline", "u"), ("overline", "o")]
        for (field, tag) in fields {
            let stateKey = stateName.map { "format-\($0)-\(field)" }
            if let value = stateKey.flatMap(options.string) ?? options.string("format-\(field)") {
                opening += "%{\(tag)\(value)}"
                closing = "%{\(tag)-}" + closing
            }
        }
        let fontKey = stateName.map { "format-\($0)-font" }
        if let font = fontKey.flatMap(options.integer) ?? options.integer("format-font") {
            opening += "%{T\(font)}"
            closing = "%{T-}" + closing
        }
        if !opening.isEmpty { result = opening + result + closing }
        return result
    }

    private static func parseMarkup(_ source: String, actions: [Int: String], options: PolybarScriptOptions) -> [PolybarScriptPiece] {
        var pieces: [PolybarScriptPiece] = []
        var state = MarkupState()
        let chars = Array(source)
        var literal = ""
        var index = 0

        func flush() {
            guard !literal.isEmpty else { return }
            let mergedActions = state.mergedActions(with: actions)
            appendText(literal, style: state.style(options: options), actions: mergedActions, to: &pieces)
            literal = ""
        }

        while index < chars.count {
            if chars[index] == "%", index + 1 < chars.count, chars[index + 1] == "%" {
                literal.append("%")
                index += 2
                continue
            }
            guard chars[index] == "%", index + 1 < chars.count, chars[index + 1] == "{",
                  let end = chars[(index + 2)...].firstIndex(of: "}") else {
                literal.append(chars[index])
                index += 1
                continue
            }
            flush()
            let body = String(chars[(index + 2)..<end])
            if body == "A" {
                if !state.actionStack.isEmpty { state.actionStack.removeLast() }
            } else if body.hasPrefix("A"), let action = parseAction(String(body.dropFirst())) {
                state.actionStack.append([action.button: action.command])
            } else if body == "R" {
                state.reversed.toggle()
            } else if body.hasPrefix("F") {
                state.foreground = parseMarkupColor(String(body.dropFirst()))
            } else if body.hasPrefix("B") {
                state.background = parseMarkupColor(String(body.dropFirst()))
            } else if body.hasPrefix("u") {
                state.underline = parseLineTag(String(body.dropFirst()), enabled: &state.underlineEnabled, currentColor: state.foreground)
            } else if body.hasPrefix("o") {
                state.overline = parseLineTag(String(body.dropFirst()), enabled: &state.overlineEnabled, currentColor: state.foreground)
            } else if body.hasPrefix("T") {
                let number = String(body.dropFirst())
                state.fontIndex = number == "-" ? nil : Int(number)
            } else if body.hasPrefix("O"), let offset = parseExtent(String(body.dropFirst())) {
                pieces.append(.offset(offset))
            }
            index = end + 1
        }
        flush()
        return pieces
    }

    private static func parseAction(_ value: String) -> (button: Int, command: String)? {
        guard let first = value.first, let button = Int(String(first)), (1...8).contains(button) else { return nil }
        let rest = String(value.dropFirst())
        guard rest.first == ":" else { return nil }
        var command = ""
        var escaped = false
        let body = Array(rest.dropFirst())
        guard let terminator = body.indices.reversed().first(where: { position in
            body[position] == ":" && (position == 0 || body[position - 1] != "\\")
        }) else { return nil }
        for char in body[..<terminator] {
            if escaped {
                command.append(char)
                escaped = false
            } else if char == "\\" {
                escaped = true
            } else {
                command.append(char)
            }
        }
        if escaped { command.append("\\") }
        return (button, command)
    }

    private static func parseLineTag(_ value: String, enabled: inout Bool, currentColor: NSColor?) -> NSColor? {
        if value == "-" { enabled = false; return nil }
        if value == "+" { enabled = true; return currentColor }
        if value.isEmpty { enabled.toggle(); return enabled ? currentColor : nil }
        enabled = true
        return parseMarkupColor(value)
    }

    private static func parseMarkupColor(_ value: String) -> NSColor? {
        if value == "-" { return nil }
        return polybarColor(value)
    }

    private static func parseExtent(_ value: String) -> CGFloat? {
        let cleaned = value.replacingOccurrences(of: "px", with: "").replacingOccurrences(of: "pt", with: "")
        return Double(cleaned).map { CGFloat($0) }
    }

    private static func appendText(_ text: String, style: PolybarScriptTextStyle, actions: [Int: String], to pieces: inout [PolybarScriptPiece]) {
        guard !text.isEmpty else { return }
        if case let .text(previous, previousStyle, previousActions)? = pieces.last,
           previousStyle == style, previousActions == actions {
            pieces[pieces.count - 1] = .text(previous + text, style, actions)
        } else {
            pieces.append(.text(text, style, actions))
        }
    }

    private static func polybarColor(_ value: String) -> NSColor? {
        let hex = value.hasPrefix("#") ? String(value.dropFirst()) : value
        if hex.count == 3, let number = UInt64(hex, radix: 16) {
            return NSColor(
                calibratedRed: CGFloat((number >> 8) & 0xf) / 15,
                green: CGFloat((number >> 4) & 0xf) / 15,
                blue: CGFloat(number & 0xf) / 15,
                alpha: 1
            )
        }
        guard hex.count == 6 || hex.count == 8, let number = UInt64(hex, radix: 16) else { return nil }
        if hex.count == 8 {
            return NSColor(
                calibratedRed: CGFloat((number >> 24) & 0xff) / 255,
                green: CGFloat((number >> 16) & 0xff) / 255,
                blue: CGFloat((number >> 8) & 0xff) / 255,
                alpha: CGFloat(number & 0xff) / 255
            )
        }
        return NSColor(
            calibratedRed: CGFloat((number >> 16) & 0xff) / 255,
            green: CGFloat((number >> 8) & 0xff) / 255,
            blue: CGFloat(number & 0xff) / 255,
            alpha: 1
        )
    }

    private static func interpolatedColor(at position: Double, colors: [(Int, NSColor)]) -> NSColor {
        guard colors.count > 1 else { return colors[0].1 }
        let lastStop = Double(max(1, colors.last!.0))
        let firstStop = Double(colors.first!.0)
        let stop = min(lastStop, max(firstStop, min(1, max(0, position)) * lastStop))
        let upperIndex = colors.firstIndex { Double($0.0) >= stop } ?? (colors.count - 1)
        let lowerIndex = max(0, upperIndex - 1)
        let lowerStop = Double(colors[lowerIndex].0)
        let upperStop = Double(colors[upperIndex].0)
        let amount = CGFloat(upperStop > lowerStop ? (stop - lowerStop) / (upperStop - lowerStop) : 0)
        let start = colors[lowerIndex].1.usingColorSpace(.deviceRGB) ?? colors[lowerIndex].1
        let end = colors[upperIndex].1.usingColorSpace(.deviceRGB) ?? colors[upperIndex].1
        return NSColor(
            calibratedRed: start.redComponent + (end.redComponent - start.redComponent) * amount,
            green: start.greenComponent + (end.greenComponent - start.greenComponent) * amount,
            blue: start.blueComponent + (end.blueComponent - start.blueComponent) * amount,
            alpha: start.alphaComponent + (end.alphaComponent - start.alphaComponent) * amount
        )
    }

    private static func formatNumber(_ number: Double) -> String {
        number.rounded() == number ? String(Int(number)) : String(number)
    }

    private struct MarkupState {
        var foreground: NSColor?
        var background: NSColor?
        var underline: NSColor?
        var overline: NSColor?
        var underlineEnabled = false
        var overlineEnabled = false
        var fontIndex: Int?
        var reversed = false
        var actionStack: [[Int: String]] = []

        func style(options: PolybarScriptOptions) -> PolybarScriptTextStyle {
            var fg = foreground
            var bg = background
            if reversed { swap(&fg, &bg) }
            let fontNumber = fontIndex.map { max(0, $0 - 1) } ?? 0
            let font = options.string("font-\(fontNumber)").flatMap(polybarFont)
            return PolybarScriptTextStyle(
                foreground: fg,
                background: bg,
                underline: underlineEnabled ? (underline ?? fg) : nil,
                overline: overlineEnabled ? (overline ?? fg) : nil,
                font: font
            )
        }

        func mergedActions(with defaults: [Int: String]) -> [Int: String] {
            var result = defaults
            for scope in actionStack {
                for (button, command) in scope { result[button] = command }
            }
            return result
        }
    }
}

private func polybarFont(_ specification: String) -> NSFont? {
    let pieces = specification.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
    let name = pieces.first?.trimmingCharacters(in: .whitespaces) ?? ""
    let size = pieces.compactMap { piece -> CGFloat? in
        guard piece.lowercased().hasPrefix("pixelsize=") || piece.lowercased().hasPrefix("size=") else { return nil }
        return CGFloat(Double(piece.split(separator: "=", maxSplits: 1).last ?? "") ?? 13)
    }.first ?? 13
    if !name.isEmpty, let font = NSFont(name: name, size: size) { return font }
    return NSFont.systemFont(ofSize: size, weight: .medium)
}

private extension NSColor {
    var hexString: String {
        let color = usingColorSpace(.deviceRGB) ?? self
        let r = Int((color.redComponent * 255).rounded())
        let g = Int((color.greenComponent * 255).rounded())
        let b = Int((color.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
