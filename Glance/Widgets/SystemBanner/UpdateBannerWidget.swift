import SwiftUI

struct UpdateBannerWidget: View {
    @StateObject private var updater = AppUpdater()
    @AppStorage("showUpdateButton") private var showUpdateButton: Bool = true

    var body: some View {
        Group {
            if shouldShowButton {
                Button(action: handleUpdate) {
                    Text("Update")
                        .fontWeight(.semibold)
                }
                .buttonStyle(BannerButtonStyle(color: .blue))
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(.smooth(duration: 0.25), value: shouldShowButton)
    }
    
    private var shouldShowButton: Bool {
        showUpdateButton && updater.updateAvailable
    }

    /// Opens the GitHub releases page so the user can download via Sparkle or manually.
    private func handleUpdate() {
        NSWorkspace.shared.open(AppUpdater.releasesURL)
    }
}

struct UpdateBannerWidget_Previews: PreviewProvider {
    static var previews: some View {
        UpdateBannerWidget()
            .frame(width: 200, height: 100)
            .background(Color.black)
    }
}
