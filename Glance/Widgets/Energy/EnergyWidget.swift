import SwiftUI

struct EnergyWidget: View {
    @EnvironmentObject var configProvider: ConfigProvider
    @Environment(\.widgetFont) var widgetFont
    @ObservedObject private var energyManager = EnergyManager.shared
    @State private var rect: CGRect = .zero

    private var config: ConfigData { configProvider.config }
    private var mode: String { config["mode"]?.stringValue ?? "current" } // "current" or "total"

    private var displayValue: String {
        switch mode {
        case "total":
            let kwh = energyManager.totalEnergy
            if kwh >= 1.0 {
                return String(format: "%.2f kWh", kwh)
            } else {
                return String(format: "%.0f Wh", kwh * 1000)
            }
        default:
            // Current power in Watts
            if energyManager.currentPower >= 1000 {
                return String(format: "%.1f kW", energyManager.currentPower / 1000.0)
            } else {
                return String(format: "%.0f W", energyManager.currentPower)
            }
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "bolt.fill")
                .barStatusSymbol(size: 12, opticalYOffset: -0.1)
            Text(displayValue)
                .font(widgetFont.toFont())
                .monospacedDigit()
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
            MenuBarPopup.show(rect: rect, id: "energy") {
                EnergyPopup(energyManager: energyManager)
            }
        }
        .animation(.smooth(duration: 0.3), value: energyManager.currentPower)
    }
}

struct EnergyWidget_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            EnergyWidget()
        }
        .frame(width: 200, height: 100)
        .background(Color.black)
        .environmentObject(ConfigProvider(config: [:]))
    }
}
