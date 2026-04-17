import AppKit
import Combine
import Foundation

final class ThermalManager: ObservableObject {
    static let shared = ThermalManager()

    @Published var cpuTemperature: Double = 0
    @Published var fanSpeed: Int = 0
    @Published var isAvailable: Bool = true

    private var cancellable: AnyCancellable?

    // Delta-based publishing thresholds
    private var lastPublishedTemp: Double = -1
    private var lastPublishedFan: Int = -1
    private let tempThreshold: Double = 1.0
    private let fanThreshold: Int = 100

    private init() {
        MactopWatcher.shared.start()

        cancellable = MactopWatcher.shared.$snapshot
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.updateFromSnapshot(snapshot)
            }
    }

    deinit {
        cancellable?.cancel()
    }

    private func updateFromSnapshot(_ snapshot: MactopSnapshot) {
        let newTemp = snapshot.cpuTemperatureCelsius
        let newFan = snapshot.fanRPM

        // Only publish if values changed beyond threshold
        if abs(newTemp - lastPublishedTemp) >= tempThreshold {
            cpuTemperature = newTemp
            lastPublishedTemp = newTemp
        }
        if abs(newFan - lastPublishedFan) >= fanThreshold {
            fanSpeed = newFan
            lastPublishedFan = newFan
        }
    }

    func refresh() {
        // No-op - MactopWatcher runs continuously
    }
}
