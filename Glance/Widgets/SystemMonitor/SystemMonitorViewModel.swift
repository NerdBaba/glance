import AppKit
import Darwin
import Foundation

final class SystemMonitorViewModel: ObservableObject {
    static let shared = SystemMonitorViewModel()

    @Published var cpuUsage: Double = 0
    @Published private(set) var coreUsage: [Double] = []
    private var previousCoreTicks: [integer_t] = []
    @Published var memoryUsed: Double = 0
    @Published var memoryPressure: String = "Normal"

    /// Physical memory — constant, never @Published
    let memoryTotal: Double

    private let scheduleID = UUID()
    private var consumers: [UUID: Bool] = [:]
    private var demandGeneration = 0
    private var prevCPUInfo: host_cpu_load_info?
    private var wakeObserver: NSObjectProtocol?
    private let logger = AppLogger.shared
    private let samplingQueue = DispatchQueue(label: "SystemMonitorSampling", qos: .utility)

    // Delta-based publishing thresholds
    private var lastPublishedCPU: Double = -1
    private var lastPublishedMemory: Double = -1
    private var lastPublishedPressure: String = ""

    private let cpuThreshold: Double = 2.0
    private let memoryThreshold: Double = 0.1 * 1024 * 1024 * 1024 // 0.1 GB in bytes

    var memoryUsagePercent: Double {
        guard memoryTotal > 0 else { return 0 }
        return (memoryUsed / memoryTotal) * 100
    }

    var memoryUsedGB: Double { memoryUsed / (1024 * 1024 * 1024) }
    var memoryTotalGB: Double { memoryTotal / (1024 * 1024 * 1024) }

    init() {
        memoryTotal = Double(ProcessInfo.processInfo.physicalMemory)
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.update(resetCPU: true)
        }
    }

    deinit {
        let id = scheduleID
        if Thread.isMainThread { WidgetUpdateScheduler.shared.cancel(id) }
        else { DispatchQueue.main.async { WidgetUpdateScheduler.shared.cancel(id) } }
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
    }

    func setDemand(_ id: UUID, enabled: Bool, cores: Bool = false) {
        precondition(Thread.isMainThread)
        let wasActive = !consumers.isEmpty
        let previouslyNeededCores = consumers.values.contains(true)
        if enabled { consumers[id] = cores } else { consumers.removeValue(forKey: id) }
        let active = !consumers.isEmpty
        let needsCores = consumers.values.contains(true)
        guard active != wasActive || needsCores != previouslyNeededCores else { return }
        demandGeneration += 1
        if active {
            if !wasActive {
                WidgetUpdateScheduler.shared.schedule(scheduleID, every: 5) { [weak self] in self?.update() }
            }
            update(resetCPU: true)
        } else {
            WidgetUpdateScheduler.shared.cancel(scheduleID)
        }
    }

    private func update(resetCPU: Bool = false) {
        guard !consumers.isEmpty else { return }
        let generation = demandGeneration
        let needsCores = consumers.values.contains(true)
        samplingQueue.async { [weak self] in
            guard let self else { return }
            if resetCPU {
                self.prevCPUInfo = nil
                self.previousCoreTicks.removeAll(keepingCapacity: true)
                self.lastPublishedCPU = -1
                self.lastPublishedMemory = -1
                self.lastPublishedPressure = ""
            }
            let cpu = self.sampleCPU()
            let cores: [Double]?
            if needsCores { cores = self.sampleCoreUsage() }
            else { self.previousCoreTicks.removeAll(keepingCapacity: true); cores = nil }
            let memory = self.sampleMemory()

            DispatchQueue.main.async {
                guard generation == self.demandGeneration, !self.consumers.isEmpty else { return }
                if let cpu, self.cpuUsage != cpu { self.cpuUsage = cpu }
                if let cores, self.coreUsage != cores { self.coreUsage = cores }
                if let used = memory.used, self.memoryUsed != used { self.memoryUsed = used }
                if let pressure = memory.pressure, self.memoryPressure != pressure { self.memoryPressure = pressure }
            }
        }
    }

    // MARK: - CPU

    private func sampleCPU() -> Double? {
        guard let current = readCPUTicks() else { return nil }
        guard let prev = prevCPUInfo else {
            prevCPUInfo = current
            return nil
        }

        let userDelta = Double(current.cpu_ticks.0 &- prev.cpu_ticks.0)
        let sysDelta = Double(current.cpu_ticks.1 &- prev.cpu_ticks.1)
        let idleDelta = Double(current.cpu_ticks.2 &- prev.cpu_ticks.2)
        let niceDelta = Double(current.cpu_ticks.3 &- prev.cpu_ticks.3)
        let total = userDelta + sysDelta + idleDelta + niceDelta
        prevCPUInfo = current

        guard total > 0 else { return nil }
        let newCPU = ((userDelta + sysDelta + niceDelta) / total) * 100
        guard abs(newCPU - lastPublishedCPU) >= cpuThreshold else { return nil }
        lastPublishedCPU = newCPU
        return newCPU
    }

    private func sampleCoreUsage() -> [Double]? {
        var cpuCount: natural_t = 0
        var info: processor_info_array_t?
        var count: mach_msg_type_number_t = 0
        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &cpuCount, &info, &count) == KERN_SUCCESS,
              let info else { return nil }
        defer { vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: info)), vm_size_t(Int(count) * MemoryLayout<integer_t>.stride)) }
        let current = Array(UnsafeBufferPointer(start: info, count: Int(count)))
        let result: [Double]?
        if previousCoreTicks.count == current.count {
            result = (0..<Int(cpuCount)).map { core in
                let base = core * Int(CPU_STATE_MAX)
                let deltas = (0..<Int(CPU_STATE_MAX)).map { Double(UInt32(bitPattern: current[base + $0]) &- UInt32(bitPattern: previousCoreTicks[base + $0])) }
                let total = deltas.reduce(0, +)
                return total > 0 ? (total - deltas[Int(CPU_STATE_IDLE)]) / total * 100 : 0
            }
        } else { result = nil }
        previousCoreTicks = current
        return result
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

    private func sampleMemory() -> (used: Double?, pressure: String?) {
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
            return (nil, nil)
        }

        let pageSize = Double(vm_kernel_page_size)
        let active = Double(stats.active_count) * pageSize
        let wired = Double(stats.wire_count) * pageSize
        let compressed = Double(stats.compressor_page_count) * pageSize

        let newMemoryUsed = active + wired + compressed

        let used: Double?
        if abs(newMemoryUsed - lastPublishedMemory) >= memoryThreshold {
            lastPublishedMemory = newMemoryUsed
            used = newMemoryUsed
        } else {
            used = nil
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
            lastPublishedPressure = newPressure
            return (used, newPressure)
        }
        return (used, nil)
    }
}
