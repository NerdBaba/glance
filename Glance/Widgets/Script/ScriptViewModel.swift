import Combine
import Foundation

final class ScriptViewModel: ObservableObject {
    @Published var output: String = ""

    private var timer: Timer?
    private let command: String
    private let interval: TimeInterval

    init(command: String, interval: TimeInterval = 10) {
        self.command = command
        self.interval = max(interval, 1)
        runCommand()
        startTimer()
    }

    deinit {
        timer?.invalidate()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.runCommand()
        }
    }

    private func runCommand() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let result = Self.executeShell(self.command)
            DispatchQueue.main.async {
                let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
                if self.output != trimmed {
                    self.output = trimmed
                }
            }
        }
    }

    private static func executeShell(_ command: String) -> String {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        process.environment = ProcessInfo.processInfo.environment

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ""
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
