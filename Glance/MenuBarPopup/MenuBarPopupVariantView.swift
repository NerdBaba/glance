import SwiftUI

enum MenuBarPopupVariant: String, Equatable {
    case box, vertical, horizontal, settings
}

struct MenuBarPopupVariantView: View {
    private struct VariantOption: Identifiable {
        let variant: MenuBarPopupVariant
        let iconName: String
        let view: AnyView

        var id: MenuBarPopupVariant { variant }
    }

    private let box: AnyView?
    private let vertical: AnyView?
    private let horizontal: AnyView?
    private let settings: AnyView?

    var selectedVariant: MenuBarPopupVariant
    @State private var hovered = false
    @State private var animationValue = 0.0

    var onVariantSelected: ((MenuBarPopupVariant) -> Void)?

    init(
        selectedVariant: MenuBarPopupVariant,
        onVariantSelected: ((MenuBarPopupVariant) -> Void)? = nil,
        @ViewBuilder box: () -> some View = { EmptyView() },
        @ViewBuilder vertical: () -> some View = { EmptyView() },
        @ViewBuilder horizontal: () -> some View = { EmptyView() },
        @ViewBuilder settings: () -> some View = { EmptyView() }
    ) {
        self.selectedVariant = selectedVariant
        self.onVariantSelected = onVariantSelected

        let boxView = box()
        let verticalView = vertical()
        let horizontalView = horizontal()
        let settingsView = settings()

        self.box = (boxView is EmptyView) ? nil : AnyView(boxView)
        self.vertical =
            (verticalView is EmptyView) ? nil : AnyView(verticalView)
        self.horizontal =
            (horizontalView is EmptyView) ? nil : AnyView(horizontalView)
        self.settings =
            (settingsView is EmptyView) ? nil : AnyView(settingsView)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            content(for: selectedVariant)
                .blur(radius: animationValue * 30)
                .transition(.opacity)
        }
        .overlay(alignment: .bottomTrailing) {
            HStack(spacing: 3) {
                ForEach(availableVariants) { option in
                    variantButton(option)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 5)
            .contentShape(Rectangle())
            .opacity(hovered ? 1 : 0.0)
            .onHover { value in
                withAnimation(.easeIn(duration: 0.3)) {
                    hovered = value
                }
            }
        }
    }

    @ViewBuilder
    private func content(for variant: MenuBarPopupVariant) -> some View {
        if let view = availableVariants.first(where: { $0.variant == variant })?.view {
            view
        }
    }

    private var availableVariants: [VariantOption] {
        var options: [VariantOption] = []
        appendVariant(.box, iconName: "square.inset.filled", view: box, to: &options)
        appendVariant(
            .vertical,
            iconName: "rectangle.portrait.inset.filled",
            view: vertical,
            to: &options
        )
        appendVariant(
            .horizontal,
            iconName: "rectangle.inset.filled",
            view: horizontal,
            to: &options
        )
        appendVariant(.settings, iconName: "gearshape.fill", view: settings, to: &options)
        return options
    }

    private func appendVariant(
        _ variant: MenuBarPopupVariant,
        iconName: String,
        view: AnyView?,
        to options: inout [VariantOption]
    ) {
        guard let view else { return }
        options.append(VariantOption(variant: variant, iconName: iconName, view: view))
    }

    private func variantButton(_ option: VariantOption) -> some View {
        Button {
            transition(to: option.variant)
        } label: {
            Image(systemName: option.iconName)
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 13, height: 10)
        }
        .buttonStyle(HoverButtonStyle())
        .overlay(
            Group {
                if selectedVariant == option.variant {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        .opacity(1 - animationValue * 10)
                }
            }
        )
    }

    private func transition(to variant: MenuBarPopupVariant) {
        guard selectedVariant != variant else { return }

        withAnimation(.smooth(duration: 0.3)) {
            animationValue = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.smooth(duration: 0.3)) {
                onVariantSelected?(variant)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.smooth(duration: 0.3)) {
                animationValue = 0
            }
        }
    }
}

private struct HoverButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HoverButton(configuration: configuration)
    }

    struct HoverButton: View {
        let configuration: Configuration
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .padding(8)
                .background(isHovered ? Color.gray.opacity(0.4) : Color.clear)
                .cornerRadius(8)
                .onHover { hovering in
                    isHovered = hovering
                }
        }
    }
}
