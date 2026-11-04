import SwiftUI

/// The furthest occupied extent at each screen edge, including stacked panels.
/// Taking the maximum handles overlapping panels without counting them twice.
struct BarReservedSpace {
    private(set) var top: CGFloat = 0
    private(set) var bottom: CGFloat = 0
    private(set) var left: CGFloat = 0
    private(set) var right: CGFloat = 0

    init(config: Config, width: CGFloat) {
        var bars = [config]
        bars += (config.rootToml.additionalBars ?? [:]).values.map {
            Config(rootToml: $0, pywalColors: config.pywalColors)
        }
        for bar in bars {
            let fg = bar.experimental.foreground
            if fg.isVertical {
                let extent = max(24, fg.resolveHeight()) + max(0, fg.topMargin)
                if fg.position == "left" { left = max(left, extent) } else { right = max(right, extent) }
                continue
            }
            let scale = fg.renderingScale(for: width)
            let drawing = BarDrawingInsets(appearance: bar.appearance, foreground: fg)
            let extent = (max(1, fg.resolveHeight()) + max(0, fg.topMargin)
                + (fg.position == "bottom" ? drawing.top : drawing.bottom)) * scale
            guard extent.isFinite else { continue }
            if fg.position == "bottom" { bottom = max(bottom, extent) }
            else { top = max(top, extent) }
        }
    }
}
