import SwiftUI

struct ClipboardPopup: View {
    @ObservedObject var viewModel: ClipboardViewModel
    @ObservedObject var configManager = ConfigManager.shared
    var appearance: AppearanceConfig { configManager.config.appearance }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 14))
                    .foregroundStyle(appearance.accentColor)
                Text("Clipboard")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                if !viewModel.entries.isEmpty {
                    Button(action: { viewModel.clear() }) {
                        Text("Clear")
                            .font(.system(size: 11))
                            .opacity(0.6)
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider().opacity(0.15)

            if viewModel.entries.isEmpty {
                Text("No clipboard history")
                    .font(.system(size: 12))
                    .opacity(0.4)
                    .padding(.vertical, 8)
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(viewModel.entries) { entry in
                            Button(action: { viewModel.restore(entry) }) {
                                HStack(alignment: .top, spacing: 8) {
                                    Text(entry.text)
                                        .font(.system(size: 11))
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    Text(relativeTime(entry.timestamp))
                                        .font(.system(size: 10))
                                        .opacity(0.4)
                                        .fixedSize()
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 8)
                                .background(appearance.foregroundColor.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 240)
            }
        }
        .frame(width: 260)
        .padding(22)
    }

    private func relativeTime(_ date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return "now" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        if seconds < 86400 { return "\(seconds / 3600)h" }
        return "\(seconds / 86400)d"
    }
}
