import SwiftUI

struct BluetoothWidget: View {
    @ObservedObject private var viewModel = BluetoothViewModel.shared
    @EnvironmentObject var configProvider: ConfigProvider
    @Environment(\.widgetFont) var widgetFont
    @State private var rect: CGRect = .zero

    private var displayMode: String { configProvider.config["display-mode"]?.stringValue ?? "icon-value" }
    private var label: String { configProvider.config["label"]?.stringValue ?? "" }
    private var maxLength: Int { configProvider.config["max-length"]?.intValue ?? 10 }

    private var valueText: String {
        if viewModel.connectedCount > 0 {
            return "\(viewModel.connectedCount)"
        } else {
            return "None"
        }
    }

    private var displayText: String {
        let full = label.isEmpty ? valueText : label + " " + valueText
        if full.count > maxLength, maxLength > 3 {
            return String(full.prefix(maxLength - 3)) + "..."
        }
        return full
    }

    var body: some View {
        Group {
            switch displayMode {
            case "icon":
                Image(systemName: "wave.3.right")
                    .barStatusSymbol(size: 12, opticalYOffset: -0.1)
            case "value":
                Text(valueText)
                    .font(widgetFont.toFont())
                    .monospacedDigit()
                    .fixedSize(horizontal: true, vertical: false)
            case "icon-label-value":
                HStack(spacing: 3) {
                    Image(systemName: "wave.3.right")
                        .barStatusSymbol(size: 12, opticalYOffset: -0.1)
                    Text(displayText)
                        .font(widgetFont.toFont())
                        .monospacedDigit()
                        .fixedSize(horizontal: true, vertical: false)
                }
            case "off":
                EmptyView()
            default: // "icon-value"
                HStack(spacing: 3) {
                    Image(systemName: "wave.3.right")
                        .barStatusSymbol(size: 12, opticalYOffset: -0.1)
                    if viewModel.connectedCount > 0 {
                        Text("\(viewModel.connectedCount)")
                            .font(widgetFont.toFont())
                            .monospacedDigit()
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
            }
        }
        .barSingleLineAligned()
        .experimentalConfiguration(horizontalPadding: 8)
        .frame(maxHeight: .infinity)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { rect = geo.frame(in: .global) }
            }
        )
        .background(.black.opacity(0.001))
        .onTapGesture {
            MenuBarPopup.show(rect: rect, id: "bluetooth") {
                BluetoothPopup(viewModel: viewModel)
            }
        }
    }
}
