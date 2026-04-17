import AppKit
import Darwin
import Foundation

final class SystemMonitorViewModel: ObservableObject {
    static let shared = SystemMonitorViewModel()

    @Published var cpuUsage: Double = 0
    @Published var memoryUsed: Double = 0
    @Published var memoryPressure: String = "Normal"

    /// Physical memory — constant, never @Published
    let memoryTotal: Double

    private var timer: Timer?
    private var prevCPUInfo: host_cpu_load_info?
    private var wakeObserver: NSObjectProtocol?
    private let logger = AppLogger.shared

    // Delta-based publishing thresholds
    private var lastPublishedCPU: Double = -1
    private var lastPublishedMemory: Double = -1
    private var lastPublishedPressure: String = ""

    private let cpuThreshold: Double = 1.0
    private let memoryThreshold: Double = 0.1 * 1024 * 1024 * 1024 // 0.1 GB in bytes

    var memoryUsagePercent: Double {
        guard memoryTotal > 0 else { return 0 }
        return (memoryUsed / memoryTotal) * 100
    }

    var memoryUsedGB: Double { memoryUsed / (1024 * 1024 * 1024) }
    var memoryTotalGB: Double { memoryTotal / (1024 * 1024 * 1024) }

    init() {
        memoryTotal = Double(ProcessInfo.processInfo.physicalMemory)
        prev_CPUInfo = readCPUTicks()
        update()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.update()
        }
        timer?.tolerance = 0.5
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.prevCPUInfo = self?.readCPUTicks()
            self?.update()
        }
    }

    deinit {
        timer?.invalidate()
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
    }

    private func update() {
        updateCPU()
        updateMemory()
    }

    // MARK: - CPU

    private func updateCPU() {
        guard let current = readCPUTicks(), let prev = prevCPUInfo else {
            prevCPUInfo = readCPUTicks()
            return
        }

        let userDelta = Double(current.cpu_ticks.0 - prev.cpu_ticks.0)
        let sysDelta = Double(current.cpu_ticks.1 - prev.cpu_ticks.1)
        let idleDelta = Double(current.cpu_ticks.2 - prev.cpu_ticks.2)
        let niceDelta = Double(current.cpu_ticks.3 - prev.cpu_ticks.3)
        let total = userDelta + sysDelta + idleDelta + niceDelta

        if total > 0 {
            let newCPU = ((userDelta + sysDelta + niceDelta) / total) * 100
            if abs(newCPU - lastPublishedCPU) >= cpuThreshold {
                cpuUsage = newCPU
                lastPublishedCPU = newCPU
            }
        }
        prevCPUInfo = current
    }

    private func readCPUTicks() -> host_cpu_load_info? {
        var size = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let hostPort = mach_host_self()
        var cpuLoadInfo = host_cpu_load_info_data_t()

        let result = withUnsafeMutablePointer(to: &cpuLoadInfo) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(size)) { intPtr in
                host_statistics(hostPort, HOST_CPU_LOAD_INFO, intPtr, &size)
            }
        }

        guard result == KERN_SUCCESS else {
            logger.warning("host_statistics(HOST_CPU_LOAD_INFO) failed with code \(result)", category: .systemMonitor)
            return nil
        }
        return cpuLoadInfo
    }

    // MARK: - Memory

    private func updateMemory() {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let hostPort = mach_host_self()

        let result = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(hostPort, HOST_VM_INFO64, intPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            logger.warning("host_statistics64(HOST_VM_INFO64) failed with code \(result)", category: .systemMonitor)
            return
        }

        let pageSize = Double(vm_kernel_page_size)
        let active = Double(stats.active_count) * pageSize
        let wired = Double(stats.wire_count) * pageSize
        let compressed = Double(stats.compressor_page_count) * pageSize

        let newMemoryUsed = active + wired + compressed

        if abs(newMemoryUsed - lastPublishedMemory) >= memoryThreshold {
            memoryUsed = newMemoryUsed
            lastPublishedMemory = newMemoryUsed
        }

        // Memory pressure based on ratio — only publish on state change
        let ratio = newMemoryUsed / memoryTotal
        let newPressure: String
        if ratio > 0.85 {
            newPressure = "Critical"
        } else if ratio > 0.7 {
            newPressure = "Warning"
        } else {
            newPressure = "Normal"
        }
        if newPressure != lastPublishedPressure {
            memoryPressure = newPressure
            lastPublishedPressure = newPressure
        }
    }
}
