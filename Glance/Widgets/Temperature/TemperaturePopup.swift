import SwiftUI

struct TemperaturePopup: View {
    @ObservedObject var thermalManager: ThermalManager
    @ObservedObject var configManager = ConfigManager.shared
    var appearance: AppearanceConfig { configManager.config.appearance }

    var body: some View {
        VStack(spacing: 14) {
            // CPU
            sensorRow(
                title: "CPU Temperature",
                icon: "cpu",
                value: thermalManager.cpuTemperature,
                unit: "°C"
            )

            Divider().opacity(0.15)

            // Fan section
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "fan")
                        .font(.system(size: 14))
                        .foregroundStyle(appearance.accentColor)
                    Text("Fan Speed")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text("\(thermalManager.fanSpeed) RPM")
                        .font(.system(size: 13, weight: .medium))
                        .monospacedDigit()
                }
                .foregroundStyle(thermalManager.fanSpeed > 2500 ? .red : .primary)
            }
        }
        .frame(width: 220)
        .padding(22)
    }

    private func sensorRow(title: String, icon: String, value: Double, unit: String) -> some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(appearance.accentColor)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("\(Int(round(value)))\(unit)")
                    .font(.system(size: 13, weight: .medium))
                    .monospacedDigit()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(appearance.foregroundColor.opacity(0.12))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(temperatureColor(thermalManager.cpuTemperature))
                        .frame(width: geo.size.width * min(thermalManager.cpuTemperature / 100.0, 1.0))
                        .animation(.easeOut(duration: 0.5), value: thermalManager.cpuTemperature)
                }
            }
            .frame(height: 4)
        }
    }

    private func temperatureColor(_ temp: Double) -> Color {
        if temp > 90 { return .red }
        if temp > 75 { return .yellow }
        if temp > 60 { return .orange }
        return .green
    }
}
