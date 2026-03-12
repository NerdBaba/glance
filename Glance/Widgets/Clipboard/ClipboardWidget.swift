import SwiftUI

struct ClipboardWidget: View {
    @EnvironmentObject var configProvider: ConfigProvider
    @ObservedObject private var viewModel = ClipboardViewModel.shared
    @State private var rect: CGRect = .zero

    var body: some View {
        Image(systemName: viewModel.entryCount > 0 ? "doc.on.clipboard.fill" : "doc.on.clipboard")
            .barStatusSymbol(opticalYOffset: -0.1)
            .barSingleLineAligned()
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
                MenuBarPopup.show(rect: rect, id: "clipboard") {
                    ClipboardPopup(viewModel: viewModel)
                }
            }
            .onAppear {
                viewModel.configure(from: configProvider.config)
            }
    }
}
