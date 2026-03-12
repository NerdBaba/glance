import SwiftUI

struct BrightnessPopup: View {
    @ObservedObject var viewModel: BrightnessViewModel
    @ObservedObject var configManager = ConfigManager.shared
    var appearance: AppearanceConfig { configManager.config.appearance }

    var body: some View {
        VStack(spacing: 14) {
            if viewModel.isAvailable {
                HStack {
                    Image(systemName: viewModel.iconName)
                        .font(.system(size: 14))
                        .foregroundStyle(appearance.accentColor)
                    Text("\(viewModel.brightnessPercent)%")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                }

                HStack(spacing: 10) {
                    Image(systemName: "sun.min")
                        .font(.system(size: 10))
                        .opacity(0.4)

                    Slider(
                        value: Binding(
                            get: { viewModel.brightness },
                            set: { viewModel.setBrightness(Float($0)) }
                        ),
                        in: 0...1
                    )
                    .tint(appearance.accentColor)

                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 10))
                        .opacity(0.4)
                }

                HStack(spacing: 8) {
                    popupButton(title: "25%", systemName: "sun.min") {
                        viewModel.setBrightness(0.25)
                    }
                    popupButton(title: "50%", systemName: "circle.lefthalf.filled") {
                        viewModel.setBrightness(0.5)
                    }
                    popupButton(title: "100%", systemName: "sun.max.fill") {
                        viewModel.setBrightness(1.0)
                    }
                }

                Divider().opacity(0.15)

                VStack(alignment: .leading, spacing: 5) {
                    detailRow("Display", viewModel.displayName)
                    detailRow("Control", viewModel.backendDescription)
                }
                .font(.system(size: 12))
                .opacity(0.7)
            } else {
                HStack {
                    Image(systemName: "sun.max")
                        .font(.system(size: 14))
                        .opacity(0.5)
                    Text("Brightness")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                }

                Text("Brightness control is not available for this display. Software brightness control requires an Apple display or a built-in screen.")
                    .font(.system(size: 11))
                    .opacity(0.6)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(width: 220)
        .padding(22)
    }

    private func popupButton(title: String, systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemName)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.subheadline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(appearance.foregroundColor.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .opacity(0.5)
            Spacer()
            Text(value)
                .lineLimit(1)
        }
    }
}
