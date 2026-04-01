import SwiftUI

struct FanPopup: View {
    @ObservedObject var thermalManager: ThermalManager
    @ObservedObject var configManager = ConfigManager.shared
    var appearance: AppearanceConfig { configManager.config.appearance }

    var body: some View {
        VStack(spacing: 14) {
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

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(appearance.foregroundColor.opacity(0.12))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(fanColor)
                            .frame(width: geo.size.width * min(Double(thermalManager.fanSpeed) / 3000.0, 1.0))
                            .animation(.easeOut(duration: 0.5), value: thermalManager.fanSpeed)
                    }
                }
                .frame(height: 6)
            }

            Divider().opacity(0.15)

            VStack(alignment: .leading, spacing: 5) {
                detailRow("Estimated Max", "~3000 RPM")
                detailRow("Current Speed", "\(thermalManager.fanSpeed) RPM")
            }
            .font(.system(size: 12))
            .opacity(0.7)
        }
        .frame(width: 220)
        .padding(22)
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

    private var fanColor: Color {
        if thermalManager.fanSpeed > 2500 { return .red }
        if thermalManager.fanSpeed > 1800 { return .yellow }
        return .green
    }
}
