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
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .shadow(color: .black.opacity(0.3), radius: 3)
                .experimentalConfiguration(horizontalPadding: 10)
                .frame(maxHeight: .infinity)
                .animation(.smooth(duration: 0.2), value: viewModel.output)
        }
    }
}
