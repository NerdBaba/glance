import AppKit
import Foundation

final class MactopWatcher: ObservableObject {
    static let shared = MactopWatcher()

    @Published var latestData: [String: Any] = [:]
    @Published var isRunning = false

    private var mactopProcess: Process?
    private var outputPipe: Pipe?
    private let queue = DispatchQueue(label: "com.glance.mactop", qos: .userInitiated)

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
                        parseLine(line)
                    }
                }
            }

            process.terminate()
        } catch {
            isRunning = false
        }
    }

    private func parseLine(_ line: String) {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.latestData = json
        }
    }
}