import SwiftUI

struct BrightnessWidget: View {
    @EnvironmentObject var configProvider: ConfigProvider
    @StateObject private var viewModel = BrightnessViewModel()
    @Environment(\.widgetFont) var widgetFont
    @State private var rect: CGRect = .zero

    private var displayMode: String { configProvider.config["display-mode"]?.stringValue ?? "icon-value" }
    private var label: String { configProvider.config["label"]?.stringValue ?? "" }
    private var maxLength: Int { configProvider.config["max-length"]?.intValue ?? 10 }
    private var showPercentage: Bool {
        configProvider.config["show-percentage"]?.boolValue ?? false
    }

    private var scrollStep: Float {
        let configuredStep = configProvider.config["scroll-step"]?.doubleValue ?? 3
        return Float(max(1, min(15, configuredStep))) / 100
    }

    private var valueText: String {
        "\(viewModel.brightnessPercent)%"
    }

    private var displayText: String {
        let full = label.isEmpty ? valueText : label + " " + valueText
        if full.count > maxLength, maxLength > 3 {
            return String(full.prefix(maxLength - 3)) + "..."
        }
        return full
    }

    @ViewBuilder
    private var availableContent: some View {
        switch displayMode {
        case "icon":
            Image(systemName: viewModel.iconName)
                .barStatusSymbol(opticalYOffset: -0.15)
        case "value":
            Text(valueText)
                .font(.system(size: 13, weight: .medium))
                .monospacedDigit()
                .fixedSize(horizontal: true, vertical: false)
        case "icon-label-value":
            HStack(spacing: 5) {
                Image(systemName: viewModel.iconName)
                    .barStatusSymbol(opticalYOffset: -0.15)
                Text(displayText)
                    .font(.system(size: 13, weight: .medium))
                    .monospacedDigit()
                    .fixedSize(horizontal: true, vertical: false)
            }
        case "off":
            EmptyView()
        default: // "icon-value"
            HStack(spacing: 5) {
                Image(systemName: viewModel.iconName)
                    .barStatusSymbol(opticalYOffset: -0.15)
                Text(valueText)
                    .font(.system(size: 13, weight: .medium))
                    .monospacedDigit()
                    .fixedSize(horizontal: true, vertical: false)
            }
            .barSingleLineAligned()
        }
    }

    var body: some View {
        Group {
            if viewModel.isAvailable {
                availableContent
            } else {
                Image(systemName: "sun.max")
                    .barStatusSymbol(opticalYOffset: -0.15)
                    .foregroundStyle(.secondary)
            }
        }
        .experimentalConfiguration(horizontalPadding: 8)
        .frame(maxHeight: .infinity)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { rect = geo.frame(in: .global) }
            }
        )
        .background(.black.opacity(0.001))
        .overlay(
            viewModel.isAvailable
                ? AnyView(BrightnessScrollOverlay { delta in
                    viewModel.adjustBrightness(by: delta > 0 ? -scrollStep : scrollStep)
                })
                : AnyView(EmptyView())
        )
        .onTapGesture {
            MenuBarPopup.show(rect: rect, id: "brightness") {
                BrightnessPopup(viewModel: viewModel)
            }
        }
    }
}

// MARK: - Scroll Overlay (same pattern as VolumeScrollOverlay)

private struct BrightnessScrollOverlay: NSViewRepresentable {
    let onScroll: (CGFloat) -> Void

    func makeNSView(context: Context) -> BrightnessScrollNSView {
        let view = BrightnessScrollNSView()
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ nsView: BrightnessScrollNSView, context: Context) {
        nsView.onScroll = onScroll
    }
}

final class BrightnessScrollNSView: NSView {
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

struct BrightnessWidget_Previews: PreviewProvider {
    static var previews: some View {
        BrightnessWidget()
            .frame(width: 200, height: 100)
            .background(Color.black)
            .environmentObject(ConfigProvider(config: [:]))
    }
}
