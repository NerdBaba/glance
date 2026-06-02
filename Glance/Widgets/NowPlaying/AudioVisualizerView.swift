import SwiftUI
import Combine

// MARK: - Visualizer Position

enum VisualizerPosition: String, CaseIterable {
    case left        // Before the icon
    case afterIcon   // Between icon and text
    case right       // After the text (default)

    var label: String {
        switch self {
        case .left: return "Left of icon"
        case .afterIcon: return "After icon"
        case .right: return "Right of text"
        }
    }
}

// MARK: - Audio Visualizer View

struct AudioVisualizerView: View {
    let isPlaying: Bool
    let barCount: Int
    let color: Color
    let maxHeight: CGFloat

    @State private var currentTime: TimeInterval = Date().timeIntervalSinceReferenceDate

    // Timer fires at ~30fps; only active while view is on screen
    private let timer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    init(isPlaying: Bool, barCount: Int = 5, color: Color, maxHeight: CGFloat = 14) {
        self.isPlaying = isPlaying
        self.barCount = barCount
        self.color = color
        self.maxHeight = maxHeight
    }

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(0..<barCount, id: \.self) { i in
                let h = max(2, maxHeight * barHeight(at: i, time: currentTime))
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(color.opacity(0.8))
                    .frame(width: 3, height: h)
            }
        }
        .frame(height: maxHeight, alignment: .center)
        .onReceive(timer) { _ in
            guard isPlaying else { return }
            currentTime = Date().timeIntervalSinceReferenceDate
        }
    }

    private func barHeight(at index: Int, time: TimeInterval) -> CGFloat {
        guard isPlaying else { return 0.15 }

        let phase = Double(index) * 0.7
        // Layered sine waves at different frequencies for organic motion
        let wave1 = sin(time * 2.3 + phase) * 0.3
        let wave2 = sin(time * 3.7 + phase * 1.3) * 0.2
        let wave3 = sin(time * 1.1 + phase * 0.9) * 0.15
        let raw = 0.45 + wave1 + wave2 + wave3

        return CGFloat(max(0.15, min(1.0, raw)))
    }
}
