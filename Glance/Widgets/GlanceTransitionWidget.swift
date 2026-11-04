import SwiftUI

struct GlanceTransitionShape: Shape {
    let kind: String
    func path(in rect: CGRect) -> Path {
        let left = kind.hasSuffix("left")
        var path = Path()
        if kind.hasPrefix("round") {
            path = Ellipse().path(in: CGRect(x: left ? rect.minX : rect.minX - rect.width, y: rect.minY, width: rect.width * 2, height: rect.height))
        } else {
            path.move(to: CGPoint(x: left ? rect.maxX : rect.minX, y: rect.minY))
            if kind.hasPrefix("slash") {
                path.addLine(to: CGPoint(x: left ? rect.minX : rect.maxX, y: rect.maxY))
                path.addLine(to: CGPoint(x: left ? rect.maxX : rect.minX, y: rect.maxY))
            } else {
                path.addLine(to: CGPoint(x: left ? rect.minX : rect.maxX, y: rect.midY))
                path.addLine(to: CGPoint(x: left ? rect.maxX : rect.minX, y: rect.maxY))
            }
            path.closeSubpath()
        }
        return path
    }
}

struct GlanceTransitionWidget: View {
    let config: ConfigData
    @ObservedObject var manager: ConfigManager

    static func isDecoration(_ values: ConfigData) -> Bool {
        if values["native-decoration"]?.boolValue == true, ["text", ""].contains(values["native-source"]?.stringValue ?? "") { return true }
        let label = values["label"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return values["native-source"]?.stringValue == "text"
            && (values["native-action"]?.stringValue ?? "").isEmpty
            && ["|", "│", "┃", "¦", "─", "━"].contains(label)
    }

    static func dimensions(_ values: ConfigData, fallbackHeight: Double) -> (width: Double, height: Double) {
        let height = values["transition-height"]?.doubleValue ?? values["format-height"]?.doubleValue ?? fallbackHeight
        return (min(max(values["transition-width"]?.doubleValue ?? height / 2, 1), 100), min(max(height, 8), 160))
    }

    var body: some View {
        let kind = config["native-transition-shape"]?.stringValue ?? "original"
        let size = Self.dimensions(config, fallbackHeight: manager.config.experimental.foreground.resolveHeight())
        let palette = manager.config.pywalColors?.colors ?? []
        let before = PolybarModuleStyle.color(config["transition-left-color"]?.stringValue ?? config["label-background"]?.stringValue ?? config["format-background"]?.stringValue, palette: palette) ?? manager.config.appearance.widgetBackgroundColor
        let after = PolybarModuleStyle.color(config["transition-right-color"]?.stringValue ?? config["label-foreground"]?.stringValue ?? config["format-foreground"]?.stringValue, palette: palette) ?? manager.config.appearance.foregroundColor
        if kind == "none" {
            Color.clear.frame(width: 0)
        } else {
            ZStack {
                if kind == "line" {
                    Rectangle().fill(before).frame(width: min(2, size.width))
                } else {
                    Rectangle().fill(kind.hasSuffix("left") ? before : after)
                    GlanceTransitionShape(kind: kind).fill(kind.hasSuffix("left") ? after : before)
                }
            }
            .frame(width: size.width, height: size.height)
            .clipped().accessibilityLabel("Module transition")
        }
    }
}
