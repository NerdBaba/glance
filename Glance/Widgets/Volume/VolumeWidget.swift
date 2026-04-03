import SwiftUI

struct VolumeWidget: View {
    @EnvironmentObject var configProvider: ConfigProvider
    @Environment(\.widgetFont) var widgetFont
    @StateObject private var viewModel = VolumeViewModel()
    @State private var rect: CGRect = .zero

    private var showPercentage: Bool {
        configProvider.config["show-percentage"]?.boolValue ?? false
    }

    private var scrollStep: Float {
        let configuredStep = configProvider.config["scroll-step"]?.doubleValue ?? 3
        return Float(max(1, min(15, configuredStep))) / 100
    }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: viewModel.volumeIconName)
                .barStatusSymbol(opticalYOffset: -0.2)
            if showPercentage {
                Text(viewModel.isMuted ? "Mute" : "\(viewModel.volumePercent)%")
                    .font(widgetFont.toFont())
                    .monospacedDigit()
            }
        }
        .barSingleLineAligned()
        .shadow(color: .black.opacity(0.3), radius: 3)
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear { rect = geometry.frame(in: .global) }
                        .onChange(of: geometry.frame(in: .global)) { _, newValue in
                            rect = newValue
                        }
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

    // Forward mouse events to the responder chain so SwiftUI gestures work.
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
