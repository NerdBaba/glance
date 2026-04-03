import SwiftUI

struct WeatherWidget: View {
    @EnvironmentObject var configProvider: ConfigProvider
    @ObservedObject private var viewModel = WeatherViewModel.shared
    @Environment(\.widgetFont) var widgetFont
    @State private var rect: CGRect = .zero

    var body: some View {
        Group {
            if let temp = viewModel.temperature {
                HStack(spacing: 5) {
                    Image(systemName: viewModel.currentCondition.symbolName)
                        .barStatusSymbol(opticalYOffset: -0.15)
                        .symbolRenderingMode(.hierarchical)
                    Text(String(format: "%.0f°", temp))
                        .font(widgetFont.toFont())
                        .monospacedDigit()
                }
                .barSingleLineAligned()
                .shadow(color: .black.opacity(0.3), radius: 3)
            } else if viewModel.isLoading {
                Image(systemName: "cloud.sun.fill")
                    .barStatusSymbol(opticalYOffset: -0.15)
                    .opacity(0.5)
            } else if viewModel.lastErrorMessage != nil {
                Image(systemName: "cloud.slash.fill")
                    .barStatusSymbol(opticalYOffset: -0.15)
                    .opacity(0.6)
            }
        }
        .experimentalConfiguration(horizontalPadding: 10)
        .frame(maxHeight: .infinity)
        .onAppear {
            viewModel.configure(from: configProvider.config)
        }
        .onReceive(configProvider.$config) { config in
            viewModel.configure(from: config)
        }
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { rect = geo.frame(in: .global) }
                    .onChange(of: geo.frame(in: .global)) { _, newValue in
                        rect = newValue
                    }
            }
        )
        .background(.black.opacity(0.001))
        .onTapGesture {
            MenuBarPopup.show(rect: rect, id: "weather") {
                WeatherPopup(viewModel: viewModel)
            }
        }
        .animation(.smooth(duration: 0.3), value: viewModel.temperature)
    }
}
