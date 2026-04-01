import AppKit
import Combine
import Foundation

final class ThermalManager: ObservableObject {
    static let shared = ThermalManager()

    @Published var cpuTemperature: Double = 0
    @Published var fanSpeed: Int = 0
    @Published var isAvailable: Bool = true

    private var cancellable: AnyCancellable?

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
        var newTemp: Double = 0
        var newFan: Int = 0

        if let temps = data["temperatures"] as? [[String: Any]] {
            var totalTemp: Double = 0
            var count = 0

            for group in temps {
                if let groupName = group["group"] as? String {
                    if groupName == "CPU E-Core" || groupName == "CPU P-Core" || groupName == "CPU Die" {
                        if let avg = group["avg_celsius"] as? Double {
                            totalTemp += avg
                            count += 1
                        }
                    }
                }
            }

            if count > 0 {
                newTemp = totalTemp / Double(count)
            }
        }

        if let fans = data["fans"] as? [[String: Any]] {
            if let firstFan = fans.first, let rpm = firstFan["rpm"] as? Int {
                newFan = rpm
            }
        }

        cpuTemperature = newTemp
        fanSpeed = newFan
    }

    func refresh() {
        // No-op - MactopWatcher runs continuously
    }
}