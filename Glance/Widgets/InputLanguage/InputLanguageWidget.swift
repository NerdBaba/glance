import SwiftUI

struct InputLanguageWidget: View {
    @StateObject private var viewModel = InputLanguageViewModel()
    @Environment(\.barFont) var barFont
    @State private var rect: CGRect = .zero

    var body: some View {
        Text(viewModel.languageCode)
            .font(barFont.toFont())
            .shadow(color: .black.opacity(0.3), radius: 3)
            .experimentalConfiguration(horizontalPadding: 8)
            .frame(maxHeight: .infinity)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { rect = geo.frame(in: .global) }
                        .onChange(of: geo.frame(in: .global)) { _, newValue in
                            rect = newValue
                        }
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
