import Foundation

struct SpacesCommandRunner {
    let toolName: String
    let executableURL: URL

    private let decoder = JSONDecoder()
    private let logger = AppLogger.shared

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

    private func log(_ message: String) {
        logger.warning("\(toolName): \(message)", category: .spaces)
    }
}
