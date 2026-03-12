import SwiftUI

struct BluetoothPopup: View {
    @ObservedObject var viewModel: BluetoothViewModel
    @ObservedObject var configManager = ConfigManager.shared
    var appearance: AppearanceConfig { configManager.config.appearance }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Image(systemName: "wave.3.right")
                    .font(.system(size: 14))
                    .foregroundStyle(appearance.accentColor)
                Text("Bluetooth")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(viewModel.connectedCount > 0 ? "On" : "No Devices")
                    .font(.system(size: 11))
                    .opacity(0.5)
            }

            Divider().opacity(0.15)

            if viewModel.devices.isEmpty {
                Text("No devices connected")
                    .font(.system(size: 12))
                    .opacity(0.4)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.devices) { device in
                        HStack(spacing: 10) {
                            Image(systemName: device.icon)
                                .font(.system(size: 13))
                                .frame(width: 20)
                                .foregroundStyle(appearance.accentColor)

                            Text(device.name)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)

                            Spacer()

                            if let battery = device.batteryLevel {
                                HStack(spacing: 4) {
                                    Image(systemName: batteryIcon(battery))
                                        .font(.system(size: 10))
                                    Text("\(battery)%")
                                        .font(.system(size: 11))
                                        .monospacedDigit()
                                }
                                .foregroundStyle(batteryColor(battery))
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Divider().opacity(0.15)

            Button(action: {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.BluetoothSettings")!)
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "gear")
                        .font(.system(size: 11))
                    Text("Bluetooth Settings")
                        .font(.system(size: 12))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(appearance.foregroundColor.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
        .frame(width: 240)
        .padding(22)
    }

    private func batteryIcon(_ level: Int) -> String {
        if level > 75 { return "battery.100percent" }
        if level > 50 { return "battery.75percent" }
        if level > 25 { return "battery.50percent" }
        return "battery.25percent"
    }

    private func batteryColor(_ level: Int) -> Color {
        if level < 15 { return .red }
        if level < 30 { return .yellow }
        return appearance.foregroundColor.opacity(0.7)
    }
}
