import SwiftUI

private struct ExperimentalConfigurationModifier: ViewModifier {
    @Environment(\.resolvedForegroundConfig) private var resolvedFG
    @Environment(\.appearance) private var appearance

    let horizontalPadding: CGFloat

    func body(content: Content) -> some View {
        if let fg = resolvedFG {
            let showIndividualBg = fg.formation == .islands && fg.widgetsBackgroundDisplayed

            Group {
                if showIndividualBg {
                    content
                        .frame(height: fg.height < 45 ? 30 : 38)
                        .padding(
                            .horizontal,
                            fg.height < 45 && horizontalPadding != 15
                                ? 0
                                : fg.height < 30
                                    ? 0 : horizontalPadding
                        )
                        .widgetStyle(
                            appearance,
                            heightOverride: fg.height < 45 ? 30 : 38
                        )
                } else {
                    content
                        .padding(.horizontal, horizontalPadding > 8 ? 4 : horizontalPadding)
                }
            }.scaleEffect(fg.height < 25 ? 0.9 : 1, anchor: .leading)
        } else {
            content
                .padding(.horizontal, horizontalPadding)
        }
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
