import SwiftUI

private struct ExperimentalConfigurationModifier: ViewModifier {
    @ObservedObject var configManager = ConfigManager.shared
    @Environment(\.appearance) private var appearance

    var foregroundHeight: CGFloat {
        configManager.config.experimental.foreground.resolveHeight()
    }

    let horizontalPadding: CGFloat

    func body(content: Content) -> some View {
        let fg = configManager.config.experimental.foreground
        let showIndividualBg = fg.formation == .islands && fg.widgetsBackground.displayed

        Group {
            if showIndividualBg {
                content
                    .frame(height: foregroundHeight < 45 ? 30 : 38)
                    .padding(
                        .horizontal,
                        foregroundHeight < 45 && horizontalPadding != 15
                            ? 0
                            : foregroundHeight < 30
                                ? 0 : horizontalPadding
                    )
                    .widgetStyle(
                        appearance,
                        heightOverride: foregroundHeight < 45 ? 30 : 38
                    )
            } else {
                content
                    .padding(.horizontal, horizontalPadding > 8 ? 4 : horizontalPadding)
            }
        }.scaleEffect(foregroundHeight < 25 ? 0.9 : 1, anchor: .leading)
    }
}

extension View {
    func experimentalConfiguration(
        horizontalPadding: CGFloat = 15
    ) -> some View {
        self.modifier(
            ExperimentalConfigurationModifier(
                horizontalPadding: horizontalPadding
            ))
    }

    func barSingleLineAligned(opticalYOffset: CGFloat = 0) -> some View {
        self.modifier(BarSingleLineAlignmentModifier(opticalYOffset: opticalYOffset))
    }

    func barStatusSymbol(
        size: CGFloat = 13,
        width: CGFloat? = nil,
        opticalYOffset: CGFloat = 0
    ) -> some View {
        self.modifier(
            BarStatusSymbolModifier(
                size: size,
                width: width ?? size + 2,
                opticalYOffset: opticalYOffset
            )
        )
    }
}

private struct BarSingleLineAlignmentModifier: ViewModifier {
    @ObservedObject var configManager = ConfigManager.shared
    let opticalYOffset: CGFloat

    func body(content: Content) -> some View {
        let foregroundHeight = configManager.config.experimental.foreground.resolveHeight()
        let lineHeight: CGFloat = foregroundHeight < 45 ? 16 : 18

        content
            .frame(height: lineHeight, alignment: .center)
            .offset(y: opticalYOffset)
    }
}

private struct BarStatusSymbolModifier: ViewModifier {
    let size: CGFloat
    let width: CGFloat
    let opticalYOffset: CGFloat

    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: .medium))
            .frame(width: width, height: size + 2, alignment: .center)
            .offset(y: opticalYOffset)
    }
}
