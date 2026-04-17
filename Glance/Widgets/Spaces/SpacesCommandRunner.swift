import Foundation

struct SpacesCommandRunner {
    let toolName: String
    let executableURL: URL

    private let decoder = JSONDecoder()
    private let logger = AppLogger.shared

    // Cached process for batch queries — reduces process spawn overhead
    private var cachedProcess: Process?

    @discardableResult
    func run(arguments: [String]) -> Data? {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()

        process.executableURL = executableURL
        process.arguments = arguments
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            log("failed to launch \(arguments.joined(separator: " ")): \(error)")
            return nil
        }

        let output = stdout.fileHandleForReading.readDataToEndOfFile()
        let errorOutput = stderr.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let stderrText = String(data: errorOutput, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let details = stderrText.isEmpty ? "exit code \(process.terminationStatus)" : stderrText
            log("command failed (\(arguments.joined(separator: " "))): \(details)")
            return nil
        }

        return output
    }

    func decode<T: Decodable>(_ type: T.Type, arguments: [String]) -> T? {
        guard let data = run(arguments: arguments) else { return nil }

        do {
            return try decoder.decode(type, from: data)
        } catch {
            log("decode \(String(describing: type)) failed: \(error)")
            return nil
        }
    }

    /// Run multiple queries in a single process spawn using a batch command.
    /// Each query is a set of arguments, and results are returned in order.
    /// Returns nil if any query fails.
    func runBatch(arguments: [[String]]) -> [Data?]? {
        // Build a shell command that runs each query separated by a delimiter
        let delimiter = "___SPACES_BATCH_DELIMITER___"
        var commands: [String] = []
        for args in arguments {
            let quotedArgs = args.map { arg in
                "'" + arg.replacingOccurrences(of: "'", with: "'\\''") + "'"
            }
            commands.append(executableURL.path + " " + quotedArgs.joined(separator: " "))
        }
        let batchScript = "(" + commands.joined(separator: "; echo '\n" + delimiter + "\n'; ") + ")"

        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", batchScript]
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            log("failed to launch batch: \(error)")
            return nil
        }

        let output = stdout.fileHandleForReading.readDataToEndOfFile()
        let errorOutput = stderr.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let stderrText = String(data: errorOutput, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            log("batch command failed: \(stderrText)")
            return nil
        }

        guard let fullOutput = String(data: output, encoding: .utf8) else { return nil }

        // Split by delimiter and return data for each query
        let parts = fullOutput.components(separatedBy: "\n" + delimiter + "\n")
        guard parts.count >= arguments.count else { return nil }

        return parts.prefix(arguments.count).map { part in
            part.data(using: .utf8)
        }
    }

    func decodeBatch<T: Decodable>(_ types: [T.Type], arguments: [[String]]) -> [T?]? {
        guard let results = runBatch(arguments: arguments) else { return nil }

        var decoded: [T?] = []
        for (index, data) in results.enumerated() {
            guard let data = data else { return nil }
            do {
                decoded.append(try decoder.decode(T.self, from: data))
            } catch {
                log("decode batch[\(index)] \(String(describing: types[index])) failed: \(error)")
                return nil
            }
        }
        return decoded
    }

    private func log(_ message: String) {
        logger.warning("\(toolName): \(message)", category: .spaces)
    }
}
