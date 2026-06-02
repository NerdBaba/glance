import SwiftUI

/// Widget for the menu, displaying Wi‑Fi and Ethernet icons.
struct NetworkWidget: View {
    @ObservedObject private var viewModel = NetworkStatusViewModel.shared
    @EnvironmentObject var configProvider: ConfigProvider
    @Environment(\.widgetFont) var widgetFont
    @State private var rect: CGRect = .zero

    // WiFi settings
    private var wifiDisplayMode: String { configProvider.config["wifi-display-mode"]?.stringValue ?? "icon-value" }
    private var wifiLabel: String { configProvider.config["wifi-label"]?.stringValue ?? "" }
    private var wifiMaxLength: Int { configProvider.config["wifi-max-length"]?.intValue ?? 10 }

    // Ethernet settings
    private var ethDisplayMode: String { configProvider.config["eth-display-mode"]?.stringValue ?? "icon-value" }
    private var ethLabel: String { configProvider.config["eth-label"]?.stringValue ?? "" }
    private var ethMaxLength: Int { configProvider.config["eth-max-length"]?.intValue ?? 10 }

    var body: some View {
        HStack(spacing: 12) {
            if viewModel.wifiState != .notSupported {
                wifiContent
            }
            if viewModel.ethernetState != .notSupported {
                ethernetContent
            }
        }
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
        .onTapGesture {
            MenuBarPopup.show(rect: rect, id: "network") { NetworkPopup() }
        }
    }

    @ViewBuilder
    private var wifiContent: some View {
        switch wifiDisplayMode {
        case "icon":
            wifiIcon
        case "value":
            // "value" mode doesn't make much sense for network, show label if set, otherwise fall back to icon
            if !wifiLabel.isEmpty {
                Text(truncated(wifiLabel, wifiMaxLength))
                    .barStatusSymbol()
            } else {
                wifiIcon
            }
        case "icon-label-value":
            HStack(spacing: 4) {
                wifiIcon
                if !wifiLabel.isEmpty {
                    Text(truncated(wifiLabel, wifiMaxLength))
                        .barStatusSymbol()
                }
            }
        case "off":
            EmptyView()
        default: // "icon-value"
            HStack(spacing: 4) {
                wifiIcon
            }
        }
    }

    @ViewBuilder
    private var ethernetContent: some View {
        switch ethDisplayMode {
        case "icon":
            ethernetIcon
        case "value":
            // "value" mode doesn't make much sense for network, show label if set, otherwise fall back to icon
            if !ethLabel.isEmpty {
                Text(truncated(ethLabel, ethMaxLength))
                    .barStatusSymbol()
            } else {
                ethernetIcon
            }
        case "icon-label-value":
            HStack(spacing: 4) {
                ethernetIcon
                if !ethLabel.isEmpty {
                    Text(truncated(ethLabel, ethMaxLength))
                        .barStatusSymbol()
                }
            }
        case "off":
            EmptyView()
        default: // "icon-value"
            HStack(spacing: 4) {
                ethernetIcon
            }
        }
    }

    @ViewBuilder
    private var wifiIcon: some View {
        switch viewModel.wifiState {
        case .connected:
            Image(systemName: "wifi").barStatusSymbol(opticalYOffset: -0.45)
        case .connecting:
            Image(systemName: "wifi")
                .barStatusSymbol(opticalYOffset: -0.45)
                .foregroundStyle(.yellow)
        case .connectedWithoutInternet:
            Image(systemName: "wifi.exclamationmark")
                .barStatusSymbol(opticalYOffset: -0.25)
                .foregroundStyle(.yellow)
        case .disconnected:
            Image(systemName: "wifi.slash")
                .barStatusSymbol(opticalYOffset: -0.35)
                .opacity(0.5)
        case .disabled:
            Image(systemName: "wifi.slash")
                .barStatusSymbol(opticalYOffset: -0.35)
                .foregroundStyle(.red)
        case .notSupported:
            Image(systemName: "wifi.exclamationmark")
                .barStatusSymbol(opticalYOffset: -0.25)
                .opacity(0.5)
        }
    }

    @ViewBuilder
    private var ethernetIcon: some View {
        switch viewModel.ethernetState {
        case .connected:
            Image(systemName: "network").barStatusSymbol(opticalYOffset: -0.2)
        case .connectedWithoutInternet:
            Image(systemName: "network")
                .barStatusSymbol(opticalYOffset: -0.2)
                .foregroundStyle(.yellow)
        case .connecting:
            Image(systemName: "network.slash")
                .barStatusSymbol(opticalYOffset: -0.1)
                .foregroundStyle(.yellow)
        case .disconnected:
            Image(systemName: "network.slash")
                .barStatusSymbol(opticalYOffset: -0.1)
                .foregroundStyle(.red)
        case .disabled, .notSupported:
            Image(systemName: "questionmark.circle")
                .barStatusSymbol(opticalYOffset: -0.1)
                .opacity(0.5)
        }
    }

    private func truncated(_ text: String, _ maxLength: Int) -> String {
        guard text.count > maxLength else { return text }
        let endIndex = text.index(text.startIndex, offsetBy: maxLength - 3)
        return String(text[..<endIndex]) + "..."
    }
}

struct NetworkWidget_Previews: PreviewProvider {
    static var previews: some View {
        NetworkWidget()
            .frame(width: 200, height: 100)
            .background(Color.black)
    }
}
