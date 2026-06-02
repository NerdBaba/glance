import SwiftUI

struct VolumeWidget: View {
    @EnvironmentObject var configProvider: ConfigProvider
    @Environment(\.widgetFont) var widgetFont
    @StateObject private var viewModel = VolumeViewModel()
    @State private var rect: CGRect = .zero

    private var displayMode: String { configProvider.config["display-mode"]?.stringValue ?? "icon-value" }
    private var label: String { configProvider.config["label"]?.stringValue ?? "" }
    private var maxLength: Int { configProvider.config["max-length"]?.intValue ?? 10 }

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
        switch displayMode {
        case "icon":
            Image(systemName: viewModel.volumeIconName)
                .barStatusSymbol(opticalYOffset: -0.2)
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
            HStack(spacing: 5) {
                Image(systemName: viewModel.volumeIconName)
                    .barStatusSymbol(opticalYOffset: -0.2)
                Text(displayText)
                    .font(widgetFont.toFont())
                    .monospacedDigit()
                    .fixedSize(horizontal: true, vertical: false)
            }
        case "off":
            EmptyView()
        default: // "icon-value"
            HStack(spacing: 5) {
                Image(systemName: viewModel.volumeIconName)
                    .barStatusSymbol(opticalYOffset: -0.2)
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
            .overlay(
                VolumeScrollOverlay { delta in
                    viewModel.adjustVolume(by: delta > 0 ? -scrollStep : scrollStep)
                }
            )
            .onTapGesture {
                MenuBarPopup.show(rect: rect, id: "volume") {
                    VolumePopup(viewModel: viewModel)
                }
            }
    }
}

/// Transparent NSView overlay that captures scroll wheel events.
private struct VolumeScrollOverlay: NSViewRepresentable {
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
