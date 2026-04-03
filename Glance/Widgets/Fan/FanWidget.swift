import SwiftUI

struct FanWidget: View {
    @EnvironmentObject var configProvider: ConfigProvider
    @Environment(\.barFont) var barFont
    @ObservedObject private var thermalManager = ThermalManager.shared
    @State private var rect: CGRect = .zero

    private var config: ConfigData { configProvider.config }
    private var showPercentage: Bool { config["show-percentage"]?.boolValue ?? false }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "fan")
                .barStatusSymbol(size: 12, opticalYOffset: -0.1)
            if showPercentage {
                // Estimate percentage based on typical max ~3000 RPM
                let percent = min(100, Int((Double(thermalManager.fanSpeed) / 3000.0) * 100))
                Text("\(percent)%")
                    .font(barFont.toFont())
                    .monospacedDigit()
            } else {
                Text("\(thermalManager.fanSpeed)")
                    .font(barFont.toFont())
                    .monospacedDigit()
            }
        }
        .barSingleLineAligned()
        .shadow(color: .black.opacity(0.3), radius: 3)
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
            MenuBarPopup.show(rect: rect, id: "fan") {
                FanPopup(thermalManager: thermalManager)
            }
        }
        .animation(.smooth(duration: 0.3), value: thermalManager.fanSpeed)
    }
}

struct FanWidget_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            FanWidget()
        }
        .frame(width: 200, height: 100)
        .background(Color.black)
        .environmentObject(ConfigProvider(config: [:]))
    }
}
