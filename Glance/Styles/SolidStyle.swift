import SwiftUI

struct SolidStyleProvider: BarStyleProvider {

    func widgetBackground(cornerRadius: CGFloat) -> AnyView {
        AnyView(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
                )
        )
    }

    func popupBackground(cornerRadius: CGFloat) -> AnyView {
        AnyView(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color(white: 0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
        )
    }

    func hoverBrightness(isHovered: Bool) -> Double {
        isHovered ? 0.06 : 0
    }

    func focusOpacity(isFocused: Bool) -> Double {
        isFocused ? 1.0 : 0.6
    }
}
