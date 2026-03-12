import SwiftUI

struct MinimalStyleProvider: BarStyleProvider {

    func widgetBackground(cornerRadius: CGFloat) -> AnyView {
        // No background — text and icons float over the desktop
        AnyView(Color.clear)
    }

    func popupBackground(cornerRadius: CGFloat) -> AnyView {
        AnyView(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.black.opacity(0.70))
                .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
        )
    }

    func hoverBrightness(isHovered: Bool) -> Double {
        isHovered ? 0.10 : 0
    }

    func focusOpacity(isFocused: Bool) -> Double {
        isFocused ? 1.0 : 0.5
    }
}
