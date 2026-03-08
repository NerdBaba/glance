import SwiftUI

struct WeatherWidget: View {
    @StateObject private var viewModel = WeatherViewModel()
    @State private var rect: CGRect = .zero

    var body: some View {
        Group {
            if let temp = viewModel.temperature {
                HStack(spacing: 5) {
                    Image(systemName: WeatherViewModel.sfSymbol(for: viewModel.weatherCode))
                        .font(.system(size: 13))
                        .symbolRenderingMode(.hierarchical)
                    Text(String(format: "%.0f°", temp))
                        .font(.system(size: 13, weight: .medium))
                        .monospacedDigit()
                }
                .shadow(color: .black.opacity(0.3), radius: 3)
            } else if viewModel.isLoading {
                Image(systemName: "cloud.fill")
                    .font(.system(size: 13))
                    .opacity(0.5)
            }
        }
        .experimentalConfiguration(horizontalPadding: 10)
        .frame(maxHeight: .infinity)
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
