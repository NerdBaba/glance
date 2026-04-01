import AppKit
import Foundation

final class EnergyManager: ObservableObject {
    static let shared = EnergyManager()

    @Published var currentPower: Double = 0
    @Published var totalEnergy: Double = 0
    @Published var batteryPercentage: Int = 0
    @Published var isCharging: Bool = false
    @Published var timeToFull: Int? = nil
    @Published var timeToEmpty: Int? = nil

    private var timer: Timer?
    private var lastUpdateTime: Date = Date()

    private init() {
        startTimer()
    }

    deinit {
        timer?.invalidate()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        refresh()
    }

    func refresh() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/mactop")
            process.arguments = ["--headless", "--format", "json", "--count", "1"]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            
            do {
                try process.run()
                process.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                
                guard let output = String(data: data, encoding: .utf8) else { return }
                
                let firstObject = self?.extractFirstJSONObject(from: output)
                guard let json = firstObject,
                      let soc = json["soc_metrics"] as? [String: Any],
                      let totalPower = soc["total_power"] as? Double else {
                    return
                }
                
                DispatchQueue.main.async {
                    self?.currentPower = totalPower
                    self?.accumulateEnergy()
                }
                
            } catch {
                // Silent fail
            }
        }
    }

    private func extractFirstJSONObject(from output: String) -> [String: Any]? {
        var depth = 0
        var inString = false
        var startIdx: Int?
        var endIdx: Int?

        for (i, char) in output.enumerated() {
            if char == "\"" {
                if i == 0 || output[output.index(output.startIndex, offsetBy: i - 1)] != "\\" {
                    inString = !inString
                }
            }
            if !inString {
                if char == "{" {
                    if depth == 0 { startIdx = i }
                    depth += 1
                } else if char == "}" {
                    depth -= 1
                    if depth == 0, let start = startIdx {
                        endIdx = i + 1
                        break
                    }
                }
            }
        }

        guard let start = startIdx, let end = endIdx else { return nil }
        let jsonStr = String(output[output.index(output.startIndex, offsetBy: start)..<output.index(output.startIndex, offsetBy: end)])

        guard let data = jsonStr.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json
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