import SwiftUI

struct SystemMonitorWidget: View {
    @EnvironmentObject var configProvider: ConfigProvider
    @ObservedObject private var viewModel = SystemMonitorViewModel.shared
    @Environment(\.widgetFont) var widgetFont
    @State private var rect: CGRect = .zero

    // CPU settings
    private var cpuDisplayMode: String { configProvider.config["cpu-display-mode"]?.stringValue ?? "icon-value" }
    private var cpuLabel: String { configProvider.config["cpu-label"]?.stringValue ?? "" }
    private var cpuMaxLength: Int { configProvider.config["cpu-max-length"]?.intValue ?? 10 }

    // Memory settings
    private var memDisplayMode: String { configProvider.config["mem-display-mode"]?.stringValue ?? "icon-value" }
    private var memLabel: String { configProvider.config["mem-label"]?.stringValue ?? "" }
    private var memMaxLength: Int { configProvider.config["mem-max-length"]?.intValue ?? 10 }

    private var cpuValueText: String {
        String(format: "%.0f%%", viewModel.cpuUsage)
    }

    private var memValueText: String {
        String(format: "%.1f", viewModel.memoryUsedGB) + "G"
    }

    private func displayText(_ label: String, _ valueText: String, _ maxLength: Int) -> String {
        let full = label.isEmpty ? valueText : label + " " + valueText
        if full.count > maxLength, maxLength > 3 {
            return String(full.prefix(maxLength - 3)) + "..."
        }
        return full
    }

    @ViewBuilder
    private var cpuView: some View {
        switch cpuDisplayMode {
        case "icon":
            Image(systemName: "cpu")
                .barStatusSymbol(size: 11, opticalYOffset: -0.1)
        case "value":
            Text(cpuValueText)
                .font(widgetFont.toFont())
                .monospacedDigit()
                .fixedSize(horizontal: true, vertical: false)
        case "icon-label-value":
            HStack(spacing: 4) {
                Image(systemName: "cpu")
                    .barStatusSymbol(size: 11, opticalYOffset: -0.1)
                Text(displayText(cpuLabel, cpuValueText, cpuMaxLength))
                    .font(widgetFont.toFont())
                    .monospacedDigit()
                    .fixedSize(horizontal: true, vertical: false)
            }
        case "off":
            EmptyView()
        default: // "icon-value"
            HStack(spacing: 4) {
                Image(systemName: "cpu")
                    .barStatusSymbol(size: 11, opticalYOffset: -0.1)
                Text(cpuValueText)
                    .font(widgetFont.toFont())
                    .monospacedDigit()
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    @ViewBuilder
    private var memView: some View {
        switch memDisplayMode {
        case "icon":
            Image(systemName: "memorychip")
                .barStatusSymbol(size: 11, opticalYOffset: -0.1)
        case "value":
            Text(memValueText)
                .font(widgetFont.toFont())
                .monospacedDigit()
                .fixedSize(horizontal: true, vertical: false)
        case "icon-label-value":
            HStack(spacing: 4) {
                Image(systemName: "memorychip")
                    .barStatusSymbol(size: 11, opticalYOffset: -0.1)
                Text(displayText(memLabel, memValueText, memMaxLength))
                    .font(widgetFont.toFont())
                    .monospacedDigit()
                    .fixedSize(horizontal: true, vertical: false)
            }
        case "off":
            EmptyView()
        default: // "icon-value"
            HStack(spacing: 4) {
                Image(systemName: "memorychip")
                    .barStatusSymbol(size: 11, opticalYOffset: -0.1)
                Text(memValueText)
                    .font(widgetFont.toFont())
                    .monospacedDigit()
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            cpuView
            memView
        }
        .drawingGroup()
        .barSingleLineAligned()
        .experimentalConfiguration(horizontalPadding: 10)
        .frame(maxHeight: .infinity)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { rect = geo.frame(in: .global) }
            }
        )
        .background(.black.opacity(0.001))
        .onTapGesture {
            MenuBarPopup.show(rect: rect, id: "systemmonitor") {
                SystemMonitorPopup(viewModel: viewModel)
            }
        }
        .animation(.smooth(duration: 0.3), value: viewModel.cpuUsage)
    }
}
