import SwiftUI

struct GlassStyleProvider: BarStyleProvider {

    func widgetBackground(cornerRadius: CGFloat) -> AnyView {
        AnyView(
            ZStack {
                // Layer 1: Base blur
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)

                // Layer 2: Top highlight gradient
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.12),
                                .white.opacity(0.03),
                                .clear,
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                // Layer 3: Inner shadow (bottom darkening)
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                .clear,
                                .clear,
                                .black.opacity(0.08),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                // Layer 4: Glass border
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.25),
                                .white.opacity(0.08),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
            }
            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        )
    }

    func popupBackground(cornerRadius: CGFloat) -> AnyView {
        AnyView(
            ZStack {
                // Base blur — thicker for popups
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)

                // Dark tint for readability
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.black.opacity(0.35))

                // Top highlight
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.10),
                                .white.opacity(0.02),
                                .clear,
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                // Inner shadow
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                .clear,
                                .clear,
                                .black.opacity(0.10),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                // Glass border
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.20),
                                .white.opacity(0.05),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
            }
            .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
        )
    }

    func hoverBrightness(isHovered: Bool) -> Double {
        isHovered ? 0.08 : 0
    }

    func focusOpacity(isFocused: Bool) -> Double {
        isFocused ? 1.0 : 0.6
    }
}
