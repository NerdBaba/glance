import SwiftUI

struct InputLanguagePopup: View {
    @ObservedObject var viewModel: InputLanguageViewModel
    @ObservedObject var configManager = ConfigManager.shared
    var appearance: AppearanceConfig { configManager.config.appearance }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Image(systemName: "keyboard")
                    .font(.system(size: 14))
                    .foregroundStyle(appearance.accentColor)
                Text("Input Source")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }

            Divider().opacity(0.15)

            HStack(spacing: 12) {
                Text(viewModel.languageCode)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(appearance.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.fullName)
                        .font(.system(size: 13, weight: .medium))
                    Text(viewModel.languageCode)
                        .font(.system(size: 11))
                        .opacity(0.5)
                }
                Spacer()
            }
        }
        .frame(width: 200)
        .padding(22)
    }
}
