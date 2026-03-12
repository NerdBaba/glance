import SwiftUI

struct VolumePopup: View {
    @ObservedObject var viewModel: VolumeViewModel
    @ObservedObject var configManager = ConfigManager.shared
    var appearance: AppearanceConfig { configManager.config.appearance }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Image(systemName: viewModel.volumeIconName)
                    .font(.system(size: 14))
                    .foregroundStyle(viewModel.isMuted ? .red : appearance.accentColor)
                Text(viewModel.isMuted ? "Muted" : "\(viewModel.volumePercent)%")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }

            HStack(spacing: 10) {
                Image(systemName: "speaker.fill")
                    .font(.system(size: 10))
                    .opacity(0.4)

                Slider(
                    value: Binding(
                        get: { viewModel.volume },
                        set: { viewModel.setVolume(Float($0)) }
                    ),
                    in: 0...1
                )
                .tint(appearance.accentColor)

                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 10))
                    .opacity(0.4)
            }

            HStack(spacing: 8) {
                popupButton(
                    title: viewModel.isMuted ? "Unmute" : "Mute",
                    systemName: viewModel.isMuted ? "speaker.wave.2.fill" : "speaker.slash.fill"
                ) {
                    viewModel.toggleMute()
                }

                popupButton(title: "-10%", systemName: "minus") {
                    viewModel.adjustVolume(by: -0.10)
                }

                popupButton(title: "+10%", systemName: "plus") {
                    viewModel.adjustVolume(by: 0.10)
                }
            }

            if !viewModel.outputDeviceName.isEmpty {
                Divider().opacity(0.15)

                HStack(spacing: 8) {
                    Image(systemName: viewModel.outputDeviceIcon)
                        .font(.system(size: 11))
                        .opacity(0.5)
                    Text(viewModel.outputDeviceName)
                        .font(.system(size: 12))
                        .opacity(0.6)
                        .lineLimit(1)
                    Spacer()
                }
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
}
