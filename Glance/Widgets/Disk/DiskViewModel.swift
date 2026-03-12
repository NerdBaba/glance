import Foundation

final class DiskViewModel: ObservableObject {
    @Published var freeBytes: Int64 = 0
    @Published var totalBytes: Int64 = 0

    private var timer: Timer?
    private let logger = AppLogger.shared

    var freeGB: Double { Double(freeBytes) / 1_073_741_824 }
    var totalGB: Double { Double(totalBytes) / 1_073_741_824 }
    var usedGB: Double { totalGB - freeGB }
    var usagePercent: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(totalBytes - freeBytes) / Double(totalBytes) * 100
    }

    init() {
        update()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.update()
        }
        timer?.tolerance = 10
    }

    deinit {
        timer?.invalidate()
    }

    private func update() {
        do {
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: "/")
            if let total = attrs[.systemSize] as? Int64 {
                totalBytes = total
            }
            if let free = attrs[.systemFreeSize] as? Int64 {
                freeBytes = free
            }
        } catch {
            logger.warning("Failed to read filesystem attributes: \(error.localizedDescription)", category: .disk)
        }
    }
}
