import SwiftUI

struct BluetoothWidget: View {
    @ObservedObject private var viewModel = BluetoothViewModel.shared
    @State private var rect: CGRect = .zero

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "wave.3.right")
                .barStatusSymbol(size: 12, opticalYOffset: -0.1)
            if viewModel.connectedCount > 0 {
                Text("\(viewModel.connectedCount)")
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
            }
        }
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
            MenuBarPopup.show(rect: rect, id: "bluetooth") {
                BluetoothPopup(viewModel: viewModel)
            }
        }
    }
}
