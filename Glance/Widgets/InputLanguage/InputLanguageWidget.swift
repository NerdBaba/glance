import SwiftUI

struct InputLanguageWidget: View {
    @StateObject private var viewModel = InputLanguageViewModel()
    @Environment(\.widgetFont) var widgetFont
    @State private var rect: CGRect = .zero

    var body: some View {
        Text(viewModel.languageCode)
            .font(widgetFont.toFont())
            .experimentalConfiguration(horizontalPadding: 8)
            .frame(maxHeight: .infinity)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { rect = geo.frame(in: .global) }
                }
            )
            .background(.black.opacity(0.001))
            .onTapGesture {
                MenuBarPopup.show(rect: rect, id: "inputlanguage") {
                    InputLanguagePopup(viewModel: viewModel)
                }
            }
    }
}
