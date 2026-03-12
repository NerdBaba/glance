import SwiftUI

struct ChangelogBannerWidget: View {
    @State private var rect: CGRect = .zero

    var body: some View {
        Button(action: openChangelog) {
            HStack {
                Text("What's new")
                    .fontWeight(.semibold)
                Image(systemName: "xmark.circle.fill")
                    .onTapGesture(perform: dismissBanner)
            }
        }
        .background(geometryTracker)
        .buttonStyle(BannerButtonStyle(color: .green.opacity(0.8)))
        .transition(.blurReplace)
    }

    private var geometryTracker: some View {
        GeometryReader { geometry in
            Color.clear
                .onAppear { rect = geometry.frame(in: .global) }
                .onChange(of: geometry.frame(in: .global)) { _, newValue in
                    rect = newValue
                }
        }
    }

    private func openChangelog() {
        MenuBarPopup.show(rect: rect, id: "changelog") {
            ChangelogPopup()
        }
    }

    private func dismissBanner() {
        NotificationCenter.default.post(
            name: Notification.Name("HideWhatsNewBanner"),
            object: nil
        )
    }
}

struct ChangelogBannerWidget_Previews: PreviewProvider {
    static var previews: some View {
        ChangelogBannerWidget()
            .frame(width: 200, height: 100)
            .background(Color.black)
    }
}
