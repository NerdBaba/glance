import SwiftUI

struct SystemStyleProvider: BarStyleProvider {

    func widgetBackground(cornerRadius: CGFloat) -> AnyView {
        AnyView(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.regularMaterial)
        )
    }

    func popupBackground(cornerRadius: CGFloat) -> AnyView {
        AnyView(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
        )
    }

    func hoverBrightness(isHovered: Bool) -> Double {
        isHovered ? 0.05 : 0
    }

    func focusOpacity(isFocused: Bool) -> Double {
        isFocused ? 1.0 : 0.6
    }
}
