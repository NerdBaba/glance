import Foundation

/// Async, non-blocking shell command runner for yabai/AeroSpace.
/// Uses Process.terminationHandler instead of waitUntilExit() to avoid thread blocking.
/// Caches output hashes to skip expensive JSON decoding when tool output hasn't changed.
struct SpacesCommandRunner {
    let toolName: String
    let executableURL: URL

    private let decoder = JSONDecoder()
    private let logger = AppLogger.shared

    // Output cache: keyed by argument string hash -> last stdout hash
    // If the same command returns identical output, we skip JSON decoding entirely.
    private var outputCache: [String: UInt64] = [:]
    private let cacheQueue = DispatchQueue(label: "com.glance.spaces.cache")

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

    /// Async decode — runs run(), checks output cache, skips JSON decoding if unchanged.
    func decode<T: Decodable>(_ type: T.Type, arguments: [String]) async -> T? {
        guard let data = await run(arguments: arguments) else { return nil }

        let cacheKey = arguments.joined(separator: " ")
        let currentHash = simpleHash(data)

        // Check cache — skip expensive JSONDecoder if output hasn't changed
        let unchanged = cacheQueue.sync { outputCache[cacheKey] == currentHash }
        if unchanged { return nil }

        // Update cache
        cacheQueue.sync { outputCache[cacheKey] = currentHash }

        do {
            return try decoder.decode(type, from: data)
        } catch {
            log("decode \(String(describing: type)) failed: \(error)")
            return nil
        }
    }

    /// Run two queries concurrently and return both results.
    func decodeTwo<A: Decodable, B: Decodable>(
        _ typeA: A.Type, argsA: [String],
        _ typeB: B.Type, argsB: [String]
    ) async -> (A?, B?) {
        async let resultA = decode(typeA, arguments: argsA)
        async let resultB = decode(typeB, arguments: argsB)
        return await (resultA, resultB)
    }

    /// Fast non-cryptographic hash — good enough for equality comparison.
    private func simpleHash(_ data: Data) -> UInt64 {
        var hash: UInt64 = 0
        let buffer = [UInt8](data)
        for byte in buffer {
            hash = hash &+ UInt64(byte)
            hash = hash &* 16777619 // FNV prime
        }
        return hash
    }

    private func log(_ message: String) {
        logger.warning("\(toolName): \(message)", category: .spaces)
    }
}
