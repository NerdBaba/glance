import Foundation

/// Async, non-blocking shell command runner for yabai/AeroSpace.
/// Uses Process.terminationHandler instead of waitUntilExit() to avoid thread blocking.
struct SpacesCommandRunner {
    let toolName: String
    let executableURL: URL

    private let decoder = JSONDecoder()
    private let logger = AppLogger.shared

    /// Async run — returns Data via continuation, never blocks a thread.
    func run(arguments: [String]) async -> Data? {
        await withCheckedContinuation { continuation in
            let process = Process()
            let stdout = Pipe()
            let stderr = Pipe()

            process.executableURL = executableURL
            process.arguments = arguments
            process.standardOutput = stdout
            process.standardError = stderr

            process.terminationHandler = { _ in
                let output = stdout.fileHandleForReading.readDataToEndOfFile()
                let errorOutput = stderr.fileHandleForReading.readDataToEndOfFile()

                guard process.terminationStatus == 0 else {
                    let stderrText = String(data: errorOutput, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let details = stderrText.isEmpty ? "exit code \(process.terminationStatus)" : stderrText
                    self.log("command failed (\(arguments.joined(separator: " "))): \(details)")
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(returning: output)
            }

            do {
                try process.run()
            } catch {
                self.log("failed to launch \(arguments.joined(separator: " ")): \(error)")
                continuation.resume(returning: nil)
            }
        }
    }

    /// Async decode — runs run() then decodes JSON.
    func decode<T: Decodable>(_ type: T.Type, arguments: [String]) async -> T? {
        guard let data = await run(arguments: arguments) else { return nil }
        do {
            return try decoder.decode(type, from: data)
        } catch {
            log("decode \(String(describing: type)) failed: \(error)")
            return nil
        }
    }

    /// Run two queries concurrently and return both results.
    /// This replaces the batch approach without using /bin/sh.
    func decodeTwo<A: Decodable, B: Decodable>(
        _ typeA: A.Type, argsA: [String],
        _ typeB: B.Type, argsB: [String]
    ) async -> (A?, B?) {
        async let resultA = decode(typeA, arguments: argsA)
        async let resultB = decode(typeB, arguments: argsB)
        return await (resultA, resultB)
    }

    private func log(_ message: String) {
        logger.warning("\(toolName): \(message)", category: .spaces)
    }
}
