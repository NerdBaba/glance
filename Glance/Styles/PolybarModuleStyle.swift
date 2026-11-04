import SwiftUI

/// The subset of Polybar's format styling that maps directly to a Glance
/// widget segment. Values are read from each widget's normal TOML config, so
/// they work for built-in widgets and `script.*` widgets alike.
struct PolybarModuleStyle {
    let background: Color?
    let foreground: Color?
    let border: Color?
    let borderWidth: CGFloat
    let cornerRadius: CGFloat
    let horizontalPadding: CGFloat
    let leadingPadding: CGFloat
    let trailingPadding: CGFloat
    let minimumWidth: CGFloat
    let height: CGFloat?
    let shape: String
    let backgroundOpacity: Double
    let alignment: Alignment
    let usesModuleLayout: Bool
    let font: FontConfig?

    var hasSegmentBackground: Bool { background != nil }
    var hasSegmentStyle: Bool { background != nil || foreground != nil || border != nil || borderWidth > 0 || leadingPadding > 0 || trailingPadding > 0 || minimumWidth > 0 || height != nil }

    static func resolve(item: TomlWidgetItem, configManager: ConfigManager) -> PolybarModuleStyle {
        let values = configManager.resolvedWidgetConfig(for: item)
        let palette = configManager.config.pywalColors?.colors ?? []
        return resolve(values: values, id: item.id, appearance: configManager.config.appearance, palette: palette)
    }

    static func resolve(values: ConfigData, id: String, appearance: AppearanceConfig, palette: [Color]) -> PolybarModuleStyle {
        let opacity = min(max(values["format-background-opacity"]?.doubleValue ?? 1, 0), 1)
        let background = color(values["format-background"]?.stringValue, palette: palette)
        let minimumWidth = min(max(values["format-min-width"]?.doubleValue ?? 0, 0), 320)
        let baseFont = appearance.useSingleFont ? appearance.barFont : appearance.widgetFont
        let hasFont = values["format-font-name"] != nil || values["format-font-size"] != nil || values["format-font-weight"] != nil
        // Script formats already expand Polybar padding into spaces or pixel
        // offsets. Applying native segment padding too would count it twice.
        let horizontalPadding: CGFloat = id.hasPrefix("script.") ? 0
            : min(max(values["format-padding"]?.doubleValue ?? (background == nil ? 0 : 4), 0), 48)
        return PolybarModuleStyle(
            background: background,
            foreground: color(values["format-foreground"]?.stringValue, palette: palette),
            border: color(values["format-border-color"]?.stringValue, palette: palette),
            borderWidth: min(max(values["format-border-width"]?.doubleValue ?? 0, 0), 8),
            cornerRadius: min(max(values["format-radius"]?.doubleValue ?? 0, 0), 40),
            horizontalPadding: horizontalPadding,
            leadingPadding: id.hasPrefix("script.") ? min(max(values["format-padding-left"]?.doubleValue ?? 0, 0), 80) : min(max(values["format-padding-left"]?.doubleValue ?? horizontalPadding, 0), 80),
            trailingPadding: id.hasPrefix("script.") ? min(max(values["format-padding-right"]?.doubleValue ?? 0, 0), 80) : min(max(values["format-padding-right"]?.doubleValue ?? horizontalPadding, 0), 80),
            minimumWidth: minimumWidth,
            height: values["format-height"]?.doubleValue.map { CGFloat(min(max($0, 20), 160)) },
            shape: values["format-shape"]?.stringValue ?? "rounded",
            backgroundOpacity: opacity,
            alignment: values["format-alignment"]?.stringValue == "left" ? .leading
                : values["format-alignment"]?.stringValue == "right" ? .trailing : .center,
            usesModuleLayout: values["format-padding"] != nil || values["format-padding-left"] != nil || values["format-padding-right"] != nil || background != nil || minimumWidth > 0,
            font: GlanceFontPolicy.usesGlobal(values, appearance: appearance) ? baseFont : hasFont ? FontConfig(
                fontName: values["format-font-name"]?.stringValue ?? baseFont.fontName,
                fontSize: values["format-font-size"]?.doubleValue.map { CGFloat(min(max($0, 1), 72)) } ?? baseFont.fontSize,
                weight: values["format-font-weight"]?.intValue.flatMap(Font.Weight.fromInt) ?? baseFont.weight
            ) : nil
        )
    }

    static func color(_ value: String?, palette: [Color]) -> Color? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        if value.lowercased() == "none" || value.lowercased() == "transparent" {
            return nil
        }

        let lowercased = value.lowercased()
        for prefix in ["pywal-index:", "pywal:"] where lowercased.hasPrefix(prefix) {
            let indexText = String(lowercased.dropFirst(prefix.count))
            guard let index = Int(indexText), palette.indices.contains(index) else { return nil }
            return palette[index]
        }

        let hex = value.hasPrefix("#") ? String(value.dropFirst()) : value
        if hex.count == 3, let number = UInt64(hex, radix: 16) {
            let red = Double((number >> 8) & 0xf) / 15
            let green = Double((number >> 4) & 0xf) / 15
            let blue = Double(number & 0xf) / 15
            return Color(.sRGB, red: red, green: green, blue: blue, opacity: 1)
        }
        guard hex.count == 6 || hex.count == 8, let number = UInt64(hex, radix: 16) else { return nil }
        if hex.count == 8 {
            // Polybar's eight digit colors are #AARRGGBB.
            let alpha = Double((number >> 24) & 0xff) / 255
            let red = Double((number >> 16) & 0xff) / 255
            let green = Double((number >> 8) & 0xff) / 255
            let blue = Double(number & 0xff) / 255
            return Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
        }
        let red = Double((number >> 16) & 0xff) / 255
        let green = Double((number >> 8) & 0xff) / 255
        let blue = Double(number & 0xff) / 255
        return Color(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }
}

private struct PolybarModuleStyleModifier: ViewModifier {
    let style: PolybarModuleStyle

    func body(content: Content) -> some View {
        content
            .padding(.leading, style.leadingPadding)
            .padding(.trailing, style.trailingPadding)
            .frame(minWidth: style.minimumWidth, alignment: style.alignment)
            .background {
                if let background = style.background {
                    GlanceModuleShape(kind: style.shape, radius: style.cornerRadius)
                        .fill(background.opacity(style.backgroundOpacity))
                }
            }
            .modifier(ModuleClipModifier(radius: style.cornerRadius, shape: style.shape))
            .overlay {
                if let border = style.border, style.borderWidth > 0 {
                    RoundedRectangle(cornerRadius: style.cornerRadius)
                        .strokeBorder(border, lineWidth: style.borderWidth)
                }
            }
    }
}

extension View {
    func polybarModuleStyle(_ style: PolybarModuleStyle) -> some View {
        modifier(PolybarModuleStyleModifier(style: style))
    }
}

private struct ModuleClipModifier: ViewModifier {
    let radius: CGFloat
    let shape: String
    @ViewBuilder func body(content: Content) -> some View {
        if radius > 0 || shape != "rounded" {
            content.clipShape(GlanceModuleShape(kind: shape, radius: radius))
        } else {
            content
        }
    }
}


private struct GlanceModuleShape: Shape {
    let kind: String
    let radius: CGFloat
    func path(in rect: CGRect) -> Path {
        guard kind == "chevron" || kind == "arrow" else { return RoundedRectangle(cornerRadius: radius).path(in: rect) }
        let cut = min(rect.height / 2, rect.width / 4)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + cut, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - (kind == "chevron" ? cut : 0), y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + cut, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}
