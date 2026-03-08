import SwiftUI

struct SystemMonitorPopup: View {
    @ObservedObject var viewModel: SystemMonitorViewModel
    @ObservedObject var configManager = ConfigManager.shared
    var appearance: AppearanceConfig { configManager.config.appearance }

    var body: some View {
        VStack(spacing: 14) {
            // CPU section
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "cpu")
                        .font(.system(size: 14))
                        .foregroundStyle(appearance.accentColor)
                    Text("CPU")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text(String(format: "%.1f%%", viewModel.cpuUsage))
                        .font(.system(size: 13, weight: .medium))
                        .monospacedDigit()
                }

                // Usage bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(appearance.foregroundColor.opacity(0.12))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(cpuColor)
                            .frame(width: geo.size.width * min(viewModel.cpuUsage / 100, 1))
                            .animation(.easeOut(duration: 0.5), value: viewModel.cpuUsage)
                    }
                }
                .frame(height: 6)
            }

            Divider().opacity(0.15)

            // Memory section
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "memorychip")
                        .font(.system(size: 14))
                        .foregroundStyle(appearance.accentColor)
                    Text("Memory")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text(String(format: "%.1f / %.0f GB",
                                viewModel.memoryUsedGB, viewModel.memoryTotalGB))
                        .font(.system(size: 13, weight: .medium))
                        .monospacedDigit()
                }

                // Usage bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(appearance.foregroundColor.opacity(0.12))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(memoryColor)
                            .frame(width: geo.size.width * min(viewModel.memoryUsagePercent / 100, 1))
                            .animation(.easeOut(duration: 0.5), value: viewModel.memoryUsagePercent)
                    }
                }
                .frame(height: 6)
            }

            Divider().opacity(0.15)

            // Details
            VStack(alignment: .leading, spacing: 5) {
                detailRow("Used", String(format: "%.1f GB", viewModel.memoryUsedGB))
                detailRow("Total", String(format: "%.0f GB", viewModel.memoryTotalGB))
                detailRow("Pressure", viewModel.memoryPressure, color: pressureColor)
            }
            .font(.system(size: 12))
            .opacity(0.7)
        }
        .frame(width: 200)
        .padding(22)
    }

    @ViewBuilder
    private func detailRow(_ label: String, _ value: String, color: Color? = nil) -> some View {
        HStack {
            Text(label)
                .opacity(0.5)
            Spacer()
            if let color = color {
                Text(value).foregroundStyle(color)
            } else {
                Text(value)
            }
        }
    }

    private var cpuColor: Color {
        if viewModel.cpuUsage > 80 { return .red }
        if viewModel.cpuUsage > 50 { return .yellow }
        return appearance.accentColor
    }

    private var memoryColor: Color {
        if viewModel.memoryUsagePercent > 85 { return .red }
        if viewModel.memoryUsagePercent > 70 { return .yellow }
        return appearance.accentColor
    }

    private var pressureColor: Color {
        switch viewModel.memoryPressure {
        case "Critical": return .red
        case "Warning": return .yellow
        default: return .green
        }
    }
}
