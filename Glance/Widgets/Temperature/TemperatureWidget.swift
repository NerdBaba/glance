import SwiftUI

struct TemperatureWidget: View {
    @EnvironmentObject var configProvider: ConfigProvider
    @ObservedObject private var thermalManager = ThermalManager.shared
    @State private var rect: CGRect = .zero

    private var config: ConfigData { configProvider.config }
    private var showUnit: Bool { config["show-unit"]?.boolValue ?? true }
    private var sensor: String { config["sensor"]?.stringValue ?? "cpu" }

    private var displayTemp: Double {
        thermalManager.cpuTemperature
    }

    private var displayUnit: String {
        "°C"
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "thermometer")
                .barStatusSymbol(size: 12, opticalYOffset: -0.1)
            Text("\(Int(round(displayTemp)))\(displayUnit)")
                .font(.system(size: 12, weight: .medium))
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
            MenuBarPopup.show(rect: rect, id: "temperature") {
                TemperaturePopup(thermalManager: thermalManager)
            }
        }
        .animation(.smooth(duration: 0.3), value: thermalManager.cpuTemperature)
    }
}

struct TemperatureWidget_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            TemperatureWidget()
        }
        .frame(width: 200, height: 100)
        .background(Color.black)
        .environmentObject(ConfigProvider(config: [:]))
    }
}
