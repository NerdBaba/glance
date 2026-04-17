import AppKit
import Combine
import Foundation

/// Selectively parsed mactop data — only the fields Glance actually uses.
struct MactopSnapshot {
    let cpuTemperatureCelsius: Double  // Average of CPU E-Core, P-Core, Die
    let fanRPM: Int
    let totalPowerWatts: Double
}

final class MactopWatcher: ObservableObject {
    static let shared = MactopWatcher()

    /// Published snapshot — only updates when parsed values actually change.
    @Published var snapshot: MactopSnapshot?
    @Published var isRunning = false

    private var mactopProcess: Process?
    private var outputPipe: Pipe?
    private let queue = DispatchQueue(label: "com.glance.mactop", qos: .userInitiated)

    // Last parsed values — used for dedup to avoid firing @Published unnecessarily
    private var lastTemp: Double = -1
    private var lastFan: Int = -1
    private var lastPower: Double = -1
    private let tempThreshold: Double = 0.5
    private let fanThreshold: Int = 50
    private let powerThreshold: Double = 0.3

    private init() {}

    func start() {
        guard !isRunning else { return }
        isRunning = true

        queue.async { [weak self] in
            self?.runMactopLoop()
        }
    }

    func stop() {
        isRunning = false
        mactopProcess?.terminate()
        mactopProcess = nil
        outputPipe = nil
    }

    private func runMactopLoop() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/mactop")
        process.arguments = ["--headless", "--format", "json"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        mactopProcess = process
        outputPipe = pipe

        do {
            try process.run()

            let handle = pipe.fileHandleForReading
            var buffer = Data()

            while isRunning {
                let available = handle.availableData
                if available.isEmpty {
                    if process.terminationStatus != 0 {
                        break
                    }
                    usleep(100000)
                    continue
                }

                buffer.append(available)

                if let newlineRange = buffer.range(of: Data([0x0A])) {
                    let lineData = buffer[buffer.startIndex..<newlineRange.lowerBound]
                    buffer = Data(buffer[newlineRange.upperBound...])

                    if let line = String(data: lineData, encoding: .utf8) {
                        parseAndPublish(line)
                    }
                }
            }

            process.terminate()
        } catch {
            isRunning = false
        }
    }

    /// Parse only the specific fields Glance needs — no full JSON tree construction.
    private func parseAndPublish(_ line: String) {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        var newTemp: Double = 0
        var newFan: Int = 0
        var newPower: Double = 0

        // Extract CPU temperature average
        if let temps = json["temperatures"] as? [[String: Any]] {
            var totalTemp: Double = 0
            var count = 0
            for group in temps {
                if let groupName = group["group"] as? String,
                   (groupName == "CPU E-Core" || groupName == "CPU P-Core" || groupName == "CPU Die"),
                   let avg = group["avg_celsius"] as? Double {
                    totalTemp += avg
                    count += 1
                }
            }
            if count > 0 { newTemp = totalTemp / Double(count) }
        }

        // Extract fan RPM
        if let fans = json["fans"] as? [[String: Any]],
           let firstFan = fans.first,
           let rpm = firstFan["rpm"] as? Int {
            newFan = rpm
        }

        // Extract power
        if let soc = json["soc_metrics"] as? [String: Any],
           let power = soc["total_power"] as? Double {
            newPower = power
        }

        // Dedup — only fire @Published if values changed meaningfully
        let tempChanged = abs(newTemp - lastTemp) >= tempThreshold
        let fanChanged = abs(newFan - lastFan) >= fanThreshold
        let powerChanged = abs(newPower - lastPower) >= powerThreshold

        guard tempChanged || fanChanged || powerChanged else { return }

        if tempChanged { lastTemp = newTemp }
        if fanChanged { lastFan = newFan }
        if powerChanged { lastPower = newPower }

        let snapshot = MactopSnapshot(
            cpuTemperatureCelsius: newTemp,
            fanRPM: newFan,
            totalPowerWatts: newPower
        )

        DispatchQueue.main.async { [weak self] in
            self?.snapshot = snapshot
        }
    }
}
