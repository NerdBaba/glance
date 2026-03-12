import SwiftUI

struct DiskPopup: View {
    @ObservedObject var viewModel: DiskViewModel
    @ObservedObject var configManager = ConfigManager.shared
    var appearance: AppearanceConfig { configManager.config.appearance }

    var body: some View {
        VStack(spacing: 14) {
            // Header
            HStack {
                Image(systemName: "internaldrive")
                    .font(.system(size: 14))
                    .foregroundStyle(appearance.accentColor)
                Text("Disk Usage")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(String(format: "%.0f%%", viewModel.usagePercent))
                    .font(.system(size: 13, weight: .medium))
                    .monospacedDigit()
            }

            // Usage bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(appearance.foregroundColor.opacity(0.12))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(usageColor)
                        .frame(width: geo.size.width * min(viewModel.usagePercent / 100, 1))
                        .animation(.easeOut(duration: 0.5), value: viewModel.usagePercent)
                }
            }
            .frame(height: 6)

            Divider().opacity(0.15)

            // Details
            VStack(alignment: .leading, spacing: 5) {
                detailRow("Used", String(format: "%.1f GB", viewModel.usedGB))
                detailRow("Free", String(format: "%.1f GB", viewModel.freeGB))
                detailRow("Total", String(format: "%.0f GB", viewModel.totalGB))
            }
            .font(.system(size: 12))
            .opacity(0.7)
        }
        .frame(width: 200)
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

    private var usageColor: Color {
        if viewModel.usagePercent > 90 { return .red }
        if viewModel.usagePercent > 75 { return .yellow }
        return appearance.accentColor
    }
}
