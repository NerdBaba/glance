import SwiftUI

struct ScriptWidget: View {
    @StateObject private var viewModel: ScriptViewModel

    init(command: String, interval: TimeInterval) {
        _viewModel = StateObject(wrappedValue: ScriptViewModel(
            command: command, interval: interval))
    }

    var body: some View {
        if !viewModel.output.isEmpty {
            Text(viewModel.output)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .lineLimit(1)
.fixedSize(horizontal: true, vertical: false)
                .experimentalConfiguration(horizontalPadding: 10)
                .frame(maxHeight: .infinity)
                .animation(.smooth(duration: 0.2), value: viewModel.output)
        }
    }
}
