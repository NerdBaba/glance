import SwiftUI

struct DiskWidget: View {
    @StateObject private var viewModel = DiskViewModel()
    @State private var rect: CGRect = .zero

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "internaldrive")
                .barStatusSymbol(size: 12, opticalYOffset: -0.1)
            Text(String(format: "%.0f GB", viewModel.freeGB))
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
        }
        .barSingleLineAligned()
        .shadow(color: .black.opacity(0.3), radius: 3)
        .experimentalConfiguration(horizontalPadding: 10)
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
            MenuBarPopup.show(rect: rect, id: "disk") {
                DiskPopup(viewModel: viewModel)
            }
        }
    }
}
