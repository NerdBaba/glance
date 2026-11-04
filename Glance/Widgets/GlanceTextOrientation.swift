import SwiftUI

/// Quarter turns keep text sharp and give layout its rotated dimensions.
struct GlanceTextOrientation: ViewModifier {
    let direction: String

    @ViewBuilder func body(content: Content) -> some View {
        if direction == "down" || direction == "up" {
            GlanceQuarterTurnLayout {
                content.fixedSize().rotationEffect(.degrees(direction == "down" ? 90 : -90))
            }
        } else { content }
    }
}

private struct GlanceQuarterTurnLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let view = subviews.first else { return .zero }
        let size = view.sizeThatFits(.unspecified)
        return CGSize(width: size.height, height: size.width)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: CGPoint(x: bounds.midX, y: bounds.midY), anchor: .center, proposal: .unspecified)
    }
}
