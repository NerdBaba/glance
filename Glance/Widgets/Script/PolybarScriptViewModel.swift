import AppKit
import Combine
import Foundation

/// Runs Polybar custom/script-compatible commands and dispatches their mouse
/// actions. Commands remain user-owned shell configuration, matching Polybar's
/// `/bin/sh -c` execution model.
final class PolybarScriptViewModel: ObservableObject {
    @Published private(set) var output = ""
    @Published private(set) var failed = false
    @Published private(set) var counter = 0
    @Published private(set) var processID: Int32?
    @Published private(set) var animationTime: TimeInterval = 0

    private let options: PolybarScriptOptions
    private let worker = DispatchQueue(label: "com.azimsukhanov.glance.polybar-script", qos: .utility)
    private let actionWorker = DispatchQueue(label: "com.azimsukhanov.glance.polybar-actions", qos: .utility)
    private let stateLock = NSLock()
    private let logger = AppLogger.shared
    private var timer: Timer?
    private var animationTimer: Timer?
    private var animationStartUptime = ProcessInfo.processInfo.systemUptime
    private var runningProcess: Process?
    private var runningActions: [Int32: Process] = [:]
    private var isExecuting = false
    private var tailBuffer = ""

    init(config: ConfigData) {
        options = PolybarScriptOptions(values: config)
        DispatchQueue.main.async { [weak self] in
            self?.startAnimationTimer()
            self?.runNow()
        }
    }

    deinit {
        timer?.invalidate()
        animationTimer?.invalidate()
        stateLock.lock()
        let process = runningProcess
        runningProcess = nil
        stateLock.unlock()
        if process?.isRunning == true { process?.terminate() }
    }

    var defaultActions: [Int: String] {
        var result: [Int: String] = [:]
        let optionsByButton: [(Int, String)] = [
            (1, "click-left"), (2, "click-middle"), (3, "click-right"),
            (4, "scroll-up"), (5, "scroll-down"),
            (6, "double-click-left"), (7, "double-click-middle"), (8, "double-click-right")
        ]
        for (button, key) in optionsByButton {
            if let command = options.string(key), !command.isEmpty { result[button] = command }
        }
        return result
    }

    func performAction(button: Int, command: String) {
        guard !command.isEmpty else { return }
        let expanded = command
            .replacingOccurrences(of: "%counter%", with: String(counter))
            .replacingOccurrences(of: "%pid%", with: processID.map(String.init) ?? "")
        let environment = scriptEnvironment()
        actionWorker.async { [weak self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = ["-c", expanded]
            process.environment = environment
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            process.terminationHandler = { [weak self] finished in
                guard let self else { return }
                if finished.terminationStatus != 0 {
                    self.logger.warning(
                        "Polybar action for button \(button) exited with code \(finished.terminationStatus)",
                        category: .script
                    )
                }
                self.actionWorker.async { [weak self] in
                    guard let self else { return }
                    self.stateLock.lock()
                    self.runningActions.removeValue(forKey: finished.processIdentifier)
                    self.stateLock.unlock()
                }
            }
            do {
                try process.run()
                self?.stateLock.lock()
                self?.runningActions[process.processIdentifier] = process
                self?.stateLock.unlock()
            } catch {
                self?.logger.warning("Failed to start Polybar action: \(error.localizedDescription)", category: .script)
            }
        }
    }

    private func runNow() {
        timer?.invalidate()
        timer = nil
        guard beginExecution() else { return }
        if options.tail {
            runTail()
        } else {
            runPollingCommand()
        }
    }

    private func startAnimationTimer() {
        guard let cadence = options.animationFrameDurations.min() else { return }
        animationStartUptime = ProcessInfo.processInfo.systemUptime
        animationTimer = Timer.scheduledTimer(withTimeInterval: max(1.0 / 60.0, cadence), repeats: true) { [weak self] _ in
            guard let self else { return }
            self.animationTime = ProcessInfo.processInfo.systemUptime - self.animationStartUptime
        }
    }

    private func runPollingCommand() {
        let command = options.command
        let timeout = options.timeout
        let intervalIf = options.intervalIf
        let intervalFail = options.intervalFail
        let fallbackInterval = max(1, options.interval)
        let condition = options.execIf
        let nextCounter = counter
        let nextPID = processID
        let environment = scriptEnvironment()

        worker.async { [weak self] in
            guard let self else { return }
            if let condition, !condition.isEmpty {
                let check = PolybarShell.run(
                    command: Self.expand(condition, counter: nextCounter, pid: nextPID),
                    timeout: timeout,
                    environment: environment
                )
                guard check.status == 0 else {
                    self.finishExecution()
                    DispatchQueue.main.async {
                        self.publish(output: "", failed: false, pid: nil)
                        self.schedule(after: intervalIf)
                    }
                    return
                }
            }

            let result = PolybarShell.run(
                command: Self.expand(command, counter: nextCounter, pid: nextPID),
                timeout: timeout,
                environment: environment
            )
            self.finishExecution()
            DispatchQueue.main.async {
                let succeeded = result.status == 0 && !result.timedOut
                let value = succeeded
                    ? result.stdout
                    : (result.stdout.isEmpty ? result.stderr : result.stdout)
                self.counter += 1
                self.publish(output: Self.firstLine(value), failed: !succeeded, pid: result.pid)
                self.schedule(after: succeeded ? fallbackInterval : intervalFail)
            }
        }
    }

    private func runTail() {
        let condition = options.execIf
        let command = options.command
        let timeout = options.timeout
        let retry = max(1, options.intervalIf)
        let nextCounter = counter
        let nextPID = processID
        let environment = scriptEnvironment()

        worker.async { [weak self] in
            guard let self else { return }
            if let condition, !condition.isEmpty {
                let check = PolybarShell.run(
                    command: Self.expand(condition, counter: nextCounter, pid: nextPID),
                    timeout: timeout,
                    environment: environment
                )
                guard check.status == 0 else {
                    self.finishExecution()
                    DispatchQueue.main.async {
                        self.publish(output: "", failed: false, pid: nil)
                        self.schedule(after: retry)
                    }
                    return
                }
            }

            let process = Process()
            let stdout = Pipe()
            let stderr = Pipe()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = ["-c", Self.expand(command, counter: nextCounter, pid: nextPID)]
            process.environment = environment
            process.standardOutput = stdout
            process.standardError = stderr
            stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty else { handle.readabilityHandler = nil; return }
                self?.receiveTailData(data)
            }
            stderr.fileHandleForReading.readabilityHandler = { handle in
                if handle.availableData.isEmpty { handle.readabilityHandler = nil }
            }

            process.terminationHandler = { [weak self] finished in
                guard let self else { return }
                stdout.fileHandleForReading.readabilityHandler = nil
                stderr.fileHandleForReading.readabilityHandler = nil
                self.finishExecution()
                DispatchQueue.main.async {
                    self.publish(output: self.output, failed: finished.terminationStatus != 0, pid: nil)
                    self.schedule(after: finished.terminationStatus == 0 ? max(1, self.options.intervalFail) : self.options.intervalFail)
                }
            }

            do {
                try process.run()
                self.stateLock.lock()
                self.runningProcess = process
                self.isExecuting = true
                self.tailBuffer = ""
                self.stateLock.unlock()
                DispatchQueue.main.async { self.publish(output: self.output, failed: false, pid: process.processIdentifier) }
                process.waitUntilExit()
            } catch {
                self.finishExecution()
                self.logger.warning("Polybar tail script failed to start: \(error.localizedDescription)", category: .script)
                DispatchQueue.main.async {
                    self.publish(output: "", failed: true, pid: nil)
                    self.schedule(after: self.options.intervalFail)
                }
            }
        }
    }

    private func receiveTailData(_ data: Data) {
        guard let chunk = String(data: data, encoding: .utf8), !chunk.isEmpty else { return }
        stateLock.lock()
        tailBuffer += chunk
        var completeLines: [String] = []
        while let newline = tailBuffer.firstIndex(of: "\n") {
            let line = String(tailBuffer[..<newline]).trimmingCharacters(in: .newlines)
            tailBuffer.removeSubrange(...newline)
            completeLines.append(line)
        }
        stateLock.unlock()
        for line in completeLines {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.counter += 1
                self.publish(output: line, failed: false, pid: self.processID)
            }
        }
    }

    private func publish(output: String, failed: Bool, pid: Int32?) {
        self.output = output
        self.failed = failed
        self.processID = pid
    }

    private func schedule(after interval: TimeInterval) {
        timer?.invalidate()
        timer = nil
        guard interval > 0 else { return }
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.runNow()
        }
        timer?.tolerance = min(1, interval * 0.2)
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
        runningProcess = nil
        isExecuting = false
        stateLock.unlock()
    }

    private static func firstLine(_ text: String) -> String {
        String(text.components(separatedBy: .newlines).first ?? "")
    }

    private static func expand(_ command: String, counter: Int, pid: Int32?) -> String {
        command
            .replacingOccurrences(of: "%counter%", with: String(counter))
            .replacingOccurrences(of: "%pid%", with: pid.map(String.init) ?? "")
    }

    private func scriptEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let paths = ["/opt/homebrew/bin", "/opt/homebrew/sbin", "/usr/local/bin", "/usr/local/sbin"]
        environment["PATH"] = (paths + [environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"])
            .joined(separator: ":")
        for (name, value) in options.environment { environment[name] = value }
        return environment
    }
}

private struct PolybarShellResult {
    let stdout: String
    let stderr: String
    let status: Int32
    let timedOut: Bool
    let pid: Int32?
}

private enum PolybarShell {
    static func run(command: String, timeout: TimeInterval, environment: [String: String]) -> PolybarShellResult {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        let lock = NSLock()
        var stdoutData = Data()
        var stderrData = Data()
        let finished = DispatchGroup()
        finished.enter()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]
        process.environment = environment
        process.standardOutput = stdout
        process.standardError = stderr
        stdout.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { handle.readabilityHandler = nil; return }
            lock.lock(); stdoutData.append(data); lock.unlock()
        }
        stderr.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { handle.readabilityHandler = nil; return }
            lock.lock(); stderrData.append(data); lock.unlock()
        }
        process.terminationHandler = { _ in finished.leave() }

        do {
            try process.run()
        } catch {
            stdout.fileHandleForReading.readabilityHandler = nil
            stderr.fileHandleForReading.readabilityHandler = nil
            return PolybarShellResult(stdout: "", stderr: error.localizedDescription, status: -1, timedOut: false, pid: nil)
        }

        let pid = process.processIdentifier
        let timedOut = finished.wait(timeout: .now() + timeout) == .timedOut
        if timedOut, process.isRunning {
            process.terminate()
            _ = finished.wait(timeout: .now() + 1)
        }
        stdout.fileHandleForReading.readabilityHandler = nil
        stderr.fileHandleForReading.readabilityHandler = nil
        lock.lock()
        let out = String(data: stdoutData, encoding: .utf8) ?? ""
        let err = String(data: stderrData, encoding: .utf8) ?? ""
        lock.unlock()
        return PolybarShellResult(stdout: out, stderr: err, status: process.terminationStatus, timedOut: timedOut, pid: pid)
    }
}
