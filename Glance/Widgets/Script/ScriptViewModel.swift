import Combine
import Foundation

final class ScriptViewModel: ObservableObject {
    @Published var output = ""
    @Published private(set) var lastRunError: String?

    private var timer: Timer?
    private let command: String
    private let interval: TimeInterval
    private let timeout: TimeInterval
    private let workerQueue = DispatchQueue(label: "com.azimsukhanov.glance.script", qos: .utility)
    private let stateLock = NSLock()
    private let logger = AppLogger.shared
    private var currentProcess: Process?
    private var isExecuting = false

    init(
        command: String,
        interval: TimeInterval = 10,
        timeout: TimeInterval = 5
    ) {
        self.command = command
        self.interval = max(interval, 1)
        self.timeout = max(timeout, 1)
        runCommand()
        startTimer()
    }

    deinit {
        timer?.invalidate()
        terminateRunningProcess()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.runCommand()
        }
        timer?.tolerance = min(1, interval * 0.2)
    }

    private func runCommand() {
        workerQueue.async { [weak self] in
            guard let self = self else { return }

            guard self.beginExecution() else { return }
            let result = self.executeShell(self.command)
            self.finishExecution()

            DispatchQueue.main.async {
                switch result {
                case .success(let output):
                    self.lastRunError = nil
                    let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    if self.output != trimmed {
                        self.output = trimmed
                    }
                case .failure(let error):
                    self.logger.warning("Script command failed: \(error)", category: .script)
                    self.lastRunError = error
                    if !self.output.isEmpty {
                        self.output = ""
                    }
                }
            }
        }
    }

    private func executeShell(_ command: String) -> ScriptExecutionResult {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        let group = DispatchGroup()

        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]
        process.standardOutput = stdout
        process.standardError = stderr
        process.environment = ProcessInfo.processInfo.environment

        group.enter()
        process.terminationHandler = { _ in
            group.leave()
        }

        do {
            try process.run()
            setCurrentProcess(process)
        } catch {
            group.leave()
            return .failure("Failed to start script: \(error.localizedDescription)")
        }

        let waitResult = group.wait(timeout: .now() + timeout)
        if waitResult == .timedOut {
            terminate(process)
            _ = group.wait(timeout: .now() + 1)
            let stderrText = String(
                data: stderr.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            )?.trimmingCharacters(in: .whitespacesAndNewlines)
            let suffix = (stderrText?.isEmpty == false) ? " \(stderrText!)" : ""
            return .failure("Script timed out after \(Int(timeout))s.\(suffix)")
        }

        let stdoutData = stdout.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderr.fileHandleForReading.readDataToEndOfFile()
        let stderrText = String(data: stderrData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard process.terminationStatus == 0 else {
            let details = stderrText.isEmpty
                ? "Script exited with code \(process.terminationStatus)."
                : stderrText
            return .failure(details)
        }

        return .success(String(data: stdoutData, encoding: .utf8) ?? "")
    }

    private func beginExecution() -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }

        guard !isExecuting else { return false }
        isExecuting = true
        return true
    }

    private func finishExecution() {
        stateLock.lock()
        currentProcess = nil
        isExecuting = false
        stateLock.unlock()
    }

    private func setCurrentProcess(_ process: Process?) {
        stateLock.lock()
        currentProcess = process
        stateLock.unlock()
    }

    private func terminateRunningProcess() {
        stateLock.lock()
        let process = currentProcess
        stateLock.unlock()
        terminate(process)
    }

    private func terminate(_ process: Process?) {
        guard let process, process.isRunning else { return }

        logger.warning("Terminating long-running script process", category: .script)
        process.interrupt()
        usleep(150_000)
        if process.isRunning {
            process.terminate()
        }
    }
}

private enum ScriptExecutionResult {
    case success(String)
    case failure(String)
}
