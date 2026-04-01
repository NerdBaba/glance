import SwiftUI

struct EnergyPopup: View {
    @ObservedObject var energyManager: EnergyManager
    @ObservedObject var configManager = ConfigManager.shared
    var appearance: AppearanceConfig { configManager.config.appearance }

    var body: some View {
        VStack(spacing: 14) {
            // Current power
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(appearance.accentColor)
                    Text("Current Power")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text(formatPower(energyManager.currentPower))
                        .font(.system(size: 13, weight: .medium))
                        .monospacedDigit()
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(appearance.foregroundColor.opacity(0.12))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(powerColor)
                            .frame(width: geo.size.width * min(energyManager.currentPower / 100.0, 1.0))
                            .animation(.easeOut(duration: 0.5), value: energyManager.currentPower)
                    }
                }
                .frame(height: 6)
            }

            Divider().opacity(0.15)

            // Energy accumulation
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "battery.100")
                        .font(.system(size: 14))
                        .foregroundStyle(appearance.accentColor)
                    Text("Accumulated Energy")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text(formatEnergy(energyManager.totalEnergy))
                        .font(.system(size: 13, weight: .medium))
                        .monospacedDigit()
                }

                HStack(spacing: 12) {
                    Button("Reset") {
                        energyManager.resetAccumulatedEnergy()
                    }
                    .font(.system(size: 11))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(appearance.foregroundColor.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .buttonStyle(.plain)

                    Text("since last reset")
                        .font(.system(size: 11))
                        .opacity(0.5)
                }
            }

            Divider().opacity(0.15)

            // Battery info (correlates with power)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: energyManager.isCharging ? "bolt.fill" : "battery.100")
                        .font(.system(size: 11))
                        .foregroundStyle(.green)
                    Text(energyManager.isCharging ? "Charging" : "Discharging")
                        .font(.system(size: 11, weight: .semibold))
                }
                detailRow("Battery", "\(energyManager.batteryPercentage)%")
                if let time = energyManager.timeToFull {
                    detailRow("Until Full", "\(time) min")
                }
                if let time = energyManager.timeToEmpty {
                    detailRow("Time to Empty", "\(time) min")
                }
            }
            .font(.system(size: 11))
            .opacity(0.7)
        }
        .frame(width: 220)
        .padding(22)
    }

    private func formatPower(_ watts: Double) -> String {
        if watts >= 1000 {
            return String(format: "%.1f kW", watts / 1000.0)
        } else {
            return String(format: "%.0f W", watts)
        }
    }

    private func formatEnergy(_ kwh: Double) -> String {
        if kwh >= 1.0 {
            return String(format: "%.3f kWh", kwh)
        } else if kwh >= 0.001 {
            return String(format: "%.1f Wh", kwh * 1000)
        } else {
            return String(format: "%.0f mWh", kwh * 1_000_000)
        }
    }

    @ViewBuilder
    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .opacity(0.5)
            Spacer()
            Text(value)
        }
    }

    private var powerColor: Color {
        if energyManager.currentPower > 80 { return .red }
        if energyManager.currentPower > 50 { return .yellow }
        return .green
    }
}
