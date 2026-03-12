import AppKit
import SwiftUI

struct BannerButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding(.vertical, 5)
            .padding(.horizontal, 10)
            .background(configuration.isPressed ? color.opacity(0.7) : color)
            .clipShape(.capsule)
    }
}

struct SystemBannerWidget: View {
    let withLeftPadding: Bool

    @State private var showWhatsNew = false

    init(withLeftPadding: Bool = false) {
        self.withLeftPadding = withLeftPadding
    }

    var body: some View {
        HStack(spacing: 15) {
            if withLeftPadding { Color.clear.frame(width: 0) }
            UpdateBannerWidget()
            if showWhatsNew { ChangelogBannerWidget() }
        }
        .onReceive(showBannerPublisher) { _ in
            setBannerVisibility(true)
        }
        .onReceive(hideBannerPublisher) { _ in
            setBannerVisibility(false)
        }
    }

    private var showBannerPublisher: NotificationCenter.Publisher {
        NotificationCenter.default.publisher(for: Notification.Name("ShowWhatsNewBanner"))
    }

    private var hideBannerPublisher: NotificationCenter.Publisher {
        NotificationCenter.default.publisher(for: Notification.Name("HideWhatsNewBanner"))
    }

    private func setBannerVisibility(_ isVisible: Bool) {
        withAnimation {
            showWhatsNew = isVisible
        }
    }
}

struct SystemBannerWidget_Previews: PreviewProvider {
    static var previews: some View {
        SystemBannerWidget()
            .frame(width: 200, height: 100)
            .background(Color.black)
    }
}
