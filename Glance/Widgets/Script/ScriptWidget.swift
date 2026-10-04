import AppKit
import SwiftUI

/// Polybar-compatible custom/script widget. The config accepts Polybar names
/// such as `exec`, `tail`, `click-left`, `format`, `ramp-volume-0`, and
/// `bar-volume-width` directly.
struct ScriptWidget: View {
    @StateObject private var viewModel: PolybarScriptViewModel
    private let config: ConfigData
    @Environment(\.widgetFont) private var widgetFont
    @Environment(\.appearance) private var appearance

    init(config: ConfigData) {
        self.config = config
        _viewModel = StateObject(wrappedValue: PolybarScriptViewModel(config: config))
    }

    /// Kept for source compatibility with older Glance call sites.
    init(command: String, interval: TimeInterval) {
        let values: ConfigData = [
            "command": .string(command),
            "interval": .double(interval)
        ]
        self.init(config: values)
    }

    private var defaultFont: NSFont {
        if let configured = config["font-0"]?.stringValue,
           let name = configured.split(separator: ":").first,
           let size = configured.split(separator: "=").last.flatMap({ CGFloat(Double($0) ?? 13) }),
           let font = NSFont(name: String(name), size: size) {
            return font
        }
        if let name = widgetFont.fontName, !name.isEmpty,
           let font = NSFont(name: name, size: widgetFont.fontSize) {
            return font
        }
        return NSFont.systemFont(ofSize: widgetFont.fontSize, weight: .medium)
    }

    var body: some View {
        let pieces = PolybarScriptRenderer.render(
            output: viewModel.output,
            config: config,
            actions: viewModel.defaultActions,
            counter: viewModel.counter,
            pid: viewModel.processID,
            failed: viewModel.failed,
            animationTime: viewModel.animationTime
        )
        HStack(spacing: 0) {
            ForEach(Array(pieces.enumerated()), id: \.offset) { _, piece in
                switch piece {
                case let .text(text, style, actions):
                    PolybarActionLabel(
                        text: text,
                        style: style,
                        actions: actions,
                        defaultFont: defaultFont,
                        defaultForeground: NSColor(appearance.foregroundColor)
                    ) { button, command in
                        viewModel.performAction(button: button, command: command)
                    }
                case let .offset(width):
                    if width >= 0 {
                        Color.clear.frame(width: width)
                    } else {
                        Color.clear.frame(width: 0).offset(x: width)
                    }
                }
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .frame(maxHeight: .infinity)
        .experimentalConfiguration(horizontalPadding: config["format-padding"]?.intValue == nil ? 4 : 0)
        .animation(.smooth(duration: 0.2), value: viewModel.output)
        .opacity(viewModel.output.isEmpty && !viewModel.failed ? 0 : 1)
        .accessibilityLabel(viewModel.output)
    }
}

private struct PolybarActionLabel: NSViewRepresentable {
    let text: String
    let style: PolybarScriptTextStyle
    let actions: [Int: String]
    let defaultFont: NSFont
    let defaultForeground: NSColor
    let perform: (Int, String) -> Void

    func makeNSView(context: Context) -> PolybarActionTextField {
        let field = PolybarActionTextField(labelWithString: text)
        field.install(text: text, style: style, actions: actions, defaultFont: defaultFont, defaultForeground: defaultForeground, perform: perform)
        return field
    }

    func updateNSView(_ field: PolybarActionTextField, context: Context) {
        field.install(text: text, style: style, actions: actions, defaultFont: defaultFont, defaultForeground: defaultForeground, perform: perform)
    }
}

private final class PolybarActionTextField: NSTextField {
    private var actions: [Int: String] = [:]
    private var perform: ((Int, String) -> Void)?
    private var overlineColor: NSColor?

    override var intrinsicContentSize: NSSize {
        let size = attributedStringValue.size()
        return NSSize(width: ceil(size.width), height: max(16, ceil(size.height)))
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    func install(
        text: String,
        style: PolybarScriptTextStyle,
        actions: [Int: String],
        defaultFont: NSFont,
        defaultForeground: NSColor,
        perform: @escaping (Int, String) -> Void
    ) {
        self.actions = actions
        self.perform = perform
        overlineColor = style.overline
        isBordered = false
        isBezeled = false
        drawsBackground = false
        isEditable = false
        isSelectable = false
        usesSingleLineMode = true
        lineBreakMode = .byClipping
        setContentCompressionResistancePriority(.required, for: .horizontal)
        let font = style.font ?? defaultFont
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: style.foreground ?? defaultForeground
        ]
        let attributed = NSMutableAttributedString(string: text, attributes: attributes)
        let range = NSRange(location: 0, length: attributed.length)
        if let background = style.background {
            attributed.addAttribute(.backgroundColor, value: background, range: range)
        }
        if let underline = style.underline {
            attributed.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            attributed.addAttribute(.underlineColor, value: underline, range: range)
        }
        attributedStringValue = attributed
        invalidateIntrinsicContentSize()
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        invoke(event.clickCount > 1 ? 6 : 1, fallback: 1)
    }

    override func rightMouseDown(with event: NSEvent) {
        invoke(event.clickCount > 1 ? 8 : 3, fallback: 3)
    }

    override func otherMouseDown(with event: NSEvent) {
        let button = event.buttonNumber == 2 ? 2 : (event.buttonNumber == 3 ? 3 : 2)
        invoke(event.clickCount > 1 ? (button == 2 ? 7 : 8) : button, fallback: button)
    }

    override func scrollWheel(with event: NSEvent) {
        if event.scrollingDeltaY > 0 {
            invoke(4, fallback: 4)
        } else if event.scrollingDeltaY < 0 {
            invoke(5, fallback: 5)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let overlineColor else { return }
        overlineColor.setStroke()
        let line = NSBezierPath()
        line.lineWidth = 1
        line.move(to: NSPoint(x: 0, y: bounds.maxY - 1))
        line.line(to: NSPoint(x: bounds.maxX, y: bounds.maxY - 1))
        line.stroke()
    }

    private func invoke(_ button: Int, fallback: Int) {
        if let command = actions[button] {
            perform?(button, command)
        } else if button != fallback, let command = actions[fallback] {
            perform?(fallback, command)
        }
    }
}
