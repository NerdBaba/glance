import SwiftUI

struct PomodoroPopup: View {
    @ObservedObject var viewModel: PomodoroViewModel
    @ObservedObject var configManager = ConfigManager.shared
    var appearance: AppearanceConfig { configManager.config.appearance }

    var body: some View {
        VStack(spacing: 14) {
            // State label
            Text(viewModel.stateLabel)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(stateColor)

            // Circular progress
            ZStack {
                Circle()
                    .stroke(appearance.foregroundColor.opacity(0.12), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: viewModel.progress)
                    .stroke(
                        stateColor,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .rotationEffect(Angle(degrees: -90))
                    .animation(.linear(duration: 1), value: viewModel.progress)

                VStack(spacing: 2) {
                    Text(viewModel.timeString)
                        .font(.system(size: 20, weight: .semibold))
                        .monospacedDigit()
                    if viewModel.currentState == .idle {
                        Text("\(viewModel.workDuration / 60) min")
                            .font(.system(size: 10))
                            .opacity(0.5)
                    }
                }
            }
            .frame(width: 80, height: 80)

            // Session dots
            HStack(spacing: 6) {
                ForEach(0..<viewModel.sessionsBeforeLongBreak, id: \.self) { index in
                    Circle()
                        .fill(index < viewModel.completedSessions
                              ? stateColor
                              : appearance.foregroundColor.opacity(0.2))
                        .frame(width: 8, height: 8)
                }
            }

            Divider().opacity(0.15)

            // Controls
            HStack(spacing: 16) {
                // Reset
                Button(action: { viewModel.reset() }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .opacity(viewModel.currentState == .idle ? 0.3 : 1)
                .disabled(viewModel.currentState == .idle)

                // Play/Pause
                Button(action: {
                    if viewModel.isRunning {
                        viewModel.pause()
                    } else {
                        viewModel.start()
                    }
                }) {
                    Image(systemName: viewModel.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 18))
                        .frame(width: 36, height: 36)
                        .background(stateColor.opacity(0.2))
                        .clipShape(Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)

                // Skip
                Button(action: { viewModel.skip() }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 14))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .opacity(viewModel.currentState == .idle ? 0.3 : 1)
                .disabled(viewModel.currentState == .idle)
            }

            // Info row
            if viewModel.currentState != .idle {
                HStack {
                    Text("Session \(viewModel.completedSessions + (viewModel.currentState == .work ? 1 : 0)) of \(viewModel.sessionsBeforeLongBreak)")
                        .font(.system(size: 11))
                        .opacity(0.5)
                }
            }
        }
        .frame(width: 200)
        .padding(22)
    }

    private var stateColor: Color {
        switch viewModel.currentState {
        case .idle: return appearance.accentColor
        case .work: return .red
        case .shortBreak: return .green
        case .longBreak: return .blue
        }
    }
}
