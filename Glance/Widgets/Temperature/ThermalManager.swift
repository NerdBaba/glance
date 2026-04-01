import AppKit
import Foundation

final class ThermalManager: ObservableObject {
    static let shared = ThermalManager()

    @Published var cpuTemperature: Double = 0
    @Published var fanSpeed: Int = 0
    @Published var isAvailable: Bool = true

    private var timer: Timer?

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
                
                guard let output = String(data: data, encoding: .utf8),
                      let jsonData = output.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]],
                      let latest = json.last else {
                    return
                }
                
                var newTemp: Double = 0
                var newFan: Int = 0
                
                if let temps = latest["temperatures"] as? [[String: Any]] {
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

                if let fans = latest["fans"] as? [[String: Any]] {
                    if let firstFan = fans.first, let rpm = firstFan["rpm"] as? Int {
                        newFan = rpm
                    }
                }
                
                DispatchQueue.main.async {
                    self?.cpuTemperature = newTemp
                    self?.fanSpeed = newFan
                }
                
            } catch {
                // Silent fail
            }
        }
    }
}