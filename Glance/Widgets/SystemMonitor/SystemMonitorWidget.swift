import SwiftUI

struct SystemMonitorWidget: View {
    @ObservedObject private var viewModel = SystemMonitorViewModel.shared
    @Environment(\.widgetFont) var widgetFont
    @State private var rect: CGRect = .zero

    var body: some View {
        HStack(spacing: 6) {
            // CPU
            HStack(spacing: 3) {
                Image(systemName: "cpu")
                    .barStatusSymbol(size: 11, opticalYOffset: -0.1)
                Text(String(format: "%.0f%%", viewModel.cpuUsage))
                    .font(widgetFont.toFont())
                    .monospacedDigit()
                    .frame(width: 42, alignment: .trailing)
            }

            // Memory
            HStack(spacing: 3) {
                Image(systemName: "memorychip")
                    .barStatusSymbol(size: 11, opticalYOffset: -0.1)
                Text(String(format: "%.1f", viewModel.memoryUsedGB) + "G")
                    .font(widgetFont.toFont())
                    .monospacedDigit()
                    .frame(width: 52, alignment: .trailing)
            }
        }
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
