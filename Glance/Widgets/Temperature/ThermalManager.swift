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