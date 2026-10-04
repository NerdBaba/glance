import SwiftUI

/// Reserve room for effects inside the native window while leaving the bar's
/// configured top/bottom margin and height unchanged.
struct BarDrawingInsets {
    let top: CGFloat
    let bottom: CGFloat

    init(appearance: AppearanceConfig, foreground: ForegroundConfig) {
        guard foreground.widgetsBackground.displayed,
              appearance.renderingStyle != .minimal else {
            top = 0
            bottom = 0
            return
        }
        let glow = appearance.glowOpacity > 0 ? Self.extent(appearance.glowRadius) : 0
        let shadow = appearance.shadowOpacity > 0 ? Self.extent(appearance.shadowRadius) : 0
        let offset = appearance.shadowY.isFinite ? appearance.shadowY : 0
        let above = ceil(max(glow, shadow > 0 ? max(0, shadow - offset) : 0))
        let below = ceil(max(glow, shadow > 0 ? max(0, shadow + offset) : 0))
        let margin = max(0, foreground.topMargin)
        top = foreground.position == "bottom" ? above : min(above, margin)
        bottom = foreground.position == "bottom" ? min(below, margin) : below
    }

    private static func extent(_ radius: CGFloat) -> CGFloat {
        radius.isFinite ? min(max(radius, 0), 128) * 3 : 0
    }
}

struct BarPanelContent: View {
    @ObservedObject private var configManager = ConfigManager.shared

    var body: some View {
        let insets = BarDrawingInsets(
            appearance: configManager.config.appearance,
            foreground: configManager.config.experimental.foreground)
        GeometryReader { geometry in
            let scale = configManager.config.experimental.foreground.renderingScale(for: geometry.size.width)
            ScaledBarContent(width: geometry.size.width)
                .padding(.top, insets.top * scale)
                .padding(.bottom, insets.bottom * scale)
        }
    }
}

/// A screenshot-based layout scales fonts, segments, spacing, and effects as a
/// single surface instead of overlapping fixed-width groups on smaller screens.
struct ScaledBarContent: View {
    let width: CGFloat
    @ObservedObject private var configManager = ConfigManager.shared

    var body: some View {
        let foreground = configManager.config.experimental.foreground
        let scale = foreground.renderingScale(for: width)
        let layoutWidth = foreground.referenceWidth > 0 ? foreground.referenceWidth : width
        let height = max(foreground.resolveHeight(), 1)
        MenuBarView()
            .frame(width: layoutWidth, height: height)
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: width, height: height * scale, alignment: .topLeading)
    }
}
