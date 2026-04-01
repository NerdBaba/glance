import AppKit
import Combine
import Foundation

final class EnergyManager: ObservableObject {
    static let shared = EnergyManager()

    @Published var currentPower: Double = 0
    @Published var totalEnergy: Double = 0
    @Published var batteryPercentage: Int = 0
    @Published var isCharging: Bool = false
    @Published var timeToFull: Int? = nil
    @Published var timeToEmpty: Int? = nil

    private var cancellable: AnyCancellable?
    private var lastUpdateTime: Date = Date()

    private init() {
        MactopWatcher.shared.start()

        cancellable = MactopWatcher.shared.$latestData
            .receive(on: DispatchQueue.main)
            .sink { [weak self] data in
                self?.parseMactopData(data)
            }
    }

    deinit {
        cancellable?.cancel()
    }

    private func parseMactopData(_ data: [String: Any]) {
        guard let soc = data["soc_metrics"] as? [String: Any],
              let totalPower = soc["total_power"] as? Double else {
            return
        }

        currentPower = totalPower
        accumulateEnergy()
    }

    private func accumulateEnergy() {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastUpdateTime)
        guard elapsed > 0 else { return }

        let powerKW = currentPower / 1000.0
        let energyKWH = powerKW * (elapsed / 3600.0)

        totalEnergy += energyKWH
        lastUpdateTime = now
    }

    func resetAccumulatedEnergy() {
        totalEnergy = 0
        lastUpdateTime = Date()
    }
}