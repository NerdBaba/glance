import SwiftUI

struct VolumeWidget: View {
    @EnvironmentObject var configProvider: ConfigProvider
    @Environment(\.widgetFont) var widgetFont
    @StateObject private var viewModel: VolumeViewModel
    @State private var rect: CGRect = .zero

    init() {
        _viewModel = StateObject(
            wrappedValue: VolumeViewModel(previewMode: Self.isPreviewRender)
        )
    }

    private static var isPreviewRender: Bool {
        ProcessInfo.processInfo.environment["GLANCE_PREVIEW_BAR_PATH"] != nil
            || CommandLine.arguments.contains("--export-bar")
            || CommandLine.arguments.contains("--preview-panel")
    }

    private var displayMode: String { configProvider.config["display-mode"]?.stringValue ?? "icon-value" }
    private var label: String { configProvider.config["label"]?.stringValue ?? "" }
    private var maxLength: Int { configProvider.config["max-length"]?.intValue ?? 10 }
    private var contentSpacing: CGFloat { configProvider.config["content-spacing"]?.doubleValue ?? 5 }
    private var previewPercent: Int {
        min(max(ProcessInfo.processInfo.environment["GLANCE_PREVIEW_VOLUME_PERCENT"].flatMap(Int.init) ?? 55, 0), 100)
    }

    private var rampEntry: (index: Int, glyph: String?)? {
        guard Self.isPreviewRender || !viewModel.isMuted else { return nil }
        var indices = Set(configProvider.config.keys.compactMap { key -> Int? in
            if key.hasPrefix("ramp-volume-") { return Int(key.dropFirst("ramp-volume-".count)) }
            if key.hasPrefix("symbol-ramp-volume-") { return Int(key.dropFirst("symbol-ramp-volume-".count)) }
            return nil
        })
        guard !indices.isEmpty else { return nil }
        if configProvider.config.keys.contains(where: { $0.hasPrefix("symbol-ramp-volume-") }) { indices.formUnion([0, 1, 2]) }
        let levels = indices.sorted()
        let percent = Self.isPreviewRender ? previewPercent : viewModel.volumePercent
        let level = levels[min(levels.count - 1, max(0, percent) * levels.count / 100)]
        return (level, configProvider.config["ramp-volume-" + String(level)]?.stringValue)
    }

    @ViewBuilder private var volumeIcon: some View {
        if let entry = rampEntry {
            PolybarIcon(config: configProvider, glyph: entry.glyph, systemName: Self.isPreviewRender ? "speaker.wave.2.fill" : viewModel.volumeIconName,
                        symbolKey: configProvider.config["symbol-ramp-volume-" + String(entry.index)] == nil ? "symbol" : "symbol-ramp-volume-" + String(entry.index))
        } else {
            PolybarIcon(config: configProvider, glyph: nil, systemName: Self.isPreviewRender ? "speaker.wave.2.fill" : viewModel.volumeIconName)
                .barStatusSymbol(opticalYOffset: -0.2)
        }
    }

    private var scrollStep: Float {
        let configuredStep = configProvider.config["scroll-step"]?.doubleValue ?? 3
        return Float(max(1, min(15, configuredStep))) / 100
    }

    private var valueText: String {
        viewModel.isMuted ? "Mute" : "\(viewModel.volumePercent)%"
    }

    private var displayText: String {
        let full = label.isEmpty ? valueText : label + " " + valueText
        if full.count > maxLength, maxLength > 3 {
            return String(full.prefix(maxLength - 3)) + "..."
        }
        return full
    }

    @ViewBuilder
    private var content: some View {
        if Self.isPreviewRender {
            previewContent
        } else {
            liveContent
        }
    }

    @ViewBuilder
    private var previewContent: some View {
        switch displayMode {
        case "icon":
            volumeIcon
        case "value":
            Text("\(previewPercent)%")
                .font(widgetFont.toFont())
                .monospacedDigit()
                .fixedSize(horizontal: true, vertical: false)
        case "label-value":
            Text(previewDisplayText)
                .font(widgetFont.toFont())
                .monospacedDigit()
                .fixedSize(horizontal: true, vertical: false)
        case "icon-label-value":
            HStack(spacing: contentSpacing) {
                volumeIcon
                Text(previewDisplayText)
                    .font(widgetFont.toFont())
                    .monospacedDigit()
                    .fixedSize(horizontal: true, vertical: false)
            }
        case "off":
            EmptyView()
        default:
            HStack(spacing: contentSpacing) {
                volumeIcon
                Text("\(previewPercent)%")
                    .font(widgetFont.toFont())
                    .monospacedDigit()
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    private var previewDisplayText: String {
        let full = label.isEmpty ? "\(previewPercent)%" : label + " \(previewPercent)%"
        guard full.count > maxLength, maxLength > 3 else { return full }
        return String(full.prefix(maxLength - 3)) + "..."
    }

    @ViewBuilder
    private var liveContent: some View {
        switch displayMode {
        case "icon":
            volumeIcon
        case "value":
            Text(valueText)
                .font(widgetFont.toFont())
                .monospacedDigit()
                .fixedSize(horizontal: true, vertical: false)
        case "label-value":
            Text(displayText)
                .font(widgetFont.toFont())
                .monospacedDigit()
                .fixedSize(horizontal: true, vertical: false)
        case "icon-label-value":
            HStack(spacing: contentSpacing) {
                volumeIcon
                Text(displayText)
                    .font(widgetFont.toFont())
                    .monospacedDigit()
                    .fixedSize(horizontal: true, vertical: false)
            }
        case "off":
            EmptyView()
        default: // "icon-value"
            HStack(spacing: contentSpacing) {
                volumeIcon
                Text(valueText)
                    .font(widgetFont.toFont())
                    .monospacedDigit()
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    var body: some View {
        content
        .barSingleLineAligned()
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear { rect = geometry.frame(in: .global) }
                }
            )
            .contentShape(Rectangle())
            .experimentalConfiguration()
            .frame(maxHeight: .infinity)
            .background(.black.opacity(0.001))
            .overlay {
                if !Self.isPreviewRender {
                    VolumeScrollOverlay { delta in
                        viewModel.adjustVolume(by: delta > 0 ? -scrollStep : scrollStep)
                    }
                }
            }
            .onTapGesture {
                MenuBarPopup.show(rect: rect, id: "volume") {
                    VolumePopup(viewModel: viewModel)
                }
            }
    }
}

/// Transparent NSView overlay that captures scroll wheel events.
struct VolumeScrollOverlay: NSViewRepresentable {
    let onScroll: (CGFloat) -> Void

    func makeNSView(context: Context) -> VolumeScrollNSView {
        let view = VolumeScrollNSView()
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ nsView: VolumeScrollNSView, context: Context) {
        nsView.onScroll = onScroll
    }
}

final class VolumeScrollNSView: NSView {
    var onScroll: ((CGFloat) -> Void)?

    override func scrollWheel(with event: NSEvent) {
        onScroll?(event.deltaY)
    }

    override func mouseDown(with event: NSEvent) {
        nextResponder?.mouseDown(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        nextResponder?.mouseUp(with: event)
    }
}

struct VolumeWidget_Previews: PreviewProvider {
    static var previews: some View {
        VolumeWidget()
            .frame(width: 200, height: 100)
            .background(Color.black)
            .environmentObject(ConfigProvider(config: [:]))
    }
}
