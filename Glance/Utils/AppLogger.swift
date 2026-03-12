import Foundation

enum AppLogCategory: String {
    case app
    case battery
    case bluetooth
    case calendar
    case clipboard
    case config
    case disk
    case nowPlaying = "now-playing"
    case script
    case systemMonitor = "system-monitor"
    case spaces
    case updates
    case weather
    case windowGap = "window-gap"
}

final class AppLogger {
    static let shared = AppLogger()

    private enum Level: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARN"
        case error = "ERROR"
    }

    private let queue = DispatchQueue(label: "com.azimsukhanov.glance.logger", qos: .utility)
    private let fileManager = FileManager.default
    private let timestampFormatter = ISO8601DateFormatter()
    private let applicationSupportFolder = "glance"
    private let logsFolder = "logs"
    private let currentLogFile = "glance.log"
    private let previousLogFile = "glance.previous.log"
    private let maxLogSizeInBytes: UInt64 = 512 * 1024

    /// Persistent file handle — kept open between writes, reopened on rotation or error.
    private var cachedHandle: FileHandle?
    private var cachedLogFileURL: URL?

    private init() {
        timestampFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    func debug(_ message: String, category: AppLogCategory = .app) {
        enqueue(level: .debug, category: category, message: message)
    }

    func info(_ message: String, category: AppLogCategory = .app) {
        enqueue(level: .info, category: category, message: message)
    }

    func warning(_ message: String, category: AppLogCategory = .app) {
        enqueue(level: .warning, category: category, message: message)
    }

    func error(_ message: String, category: AppLogCategory = .app) {
        enqueue(level: .error, category: category, message: message)
    }

    private func enqueue(level: Level, category: AppLogCategory, message: String) {
        queue.async { [weak self] in
            self?.write(level: level, category: category, message: message)
        }
    }

    private func write(level: Level, category: AppLogCategory, message: String) {
        guard let logFileURL = logFileURL() else { return }

        if rotateIfNeeded(logFileURL: logFileURL) {
            closeHandle()
        }

        let line = "[\(timestampFormatter.string(from: Date()))] [\(level.rawValue)] [\(category.rawValue)] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }

        let handle = openHandle(for: logFileURL)
        handle?.write(data)
    }

    private func openHandle(for logFileURL: URL) -> FileHandle? {
        if let handle = cachedHandle { return handle }

        if !fileManager.fileExists(atPath: logFileURL.path) {
            fileManager.createFile(atPath: logFileURL.path, contents: nil)
        }

        do {
            let handle = try FileHandle(forWritingTo: logFileURL)
            handle.seekToEndOfFile()
            cachedHandle = handle
            cachedLogFileURL = logFileURL
            return handle
        } catch {
            fputs("Glance logger failed: \(error)\n", stderr)
            return nil
        }
    }

    private func closeHandle() {
        try? cachedHandle?.close()
        cachedHandle = nil
        cachedLogFileURL = nil
    }

    /// Returns true if rotation happened (caller must close the cached handle).
    private func rotateIfNeeded(logFileURL: URL) -> Bool {
        guard
            let attributes = try? fileManager.attributesOfItem(atPath: logFileURL.path),
            let size = attributes[.size] as? NSNumber,
            size.uint64Value >= maxLogSizeInBytes
        else {
            return false
        }

        let previousLogURL = logFileURL.deletingLastPathComponent().appendingPathComponent(previousLogFile)
        try? fileManager.removeItem(at: previousLogURL)
        try? fileManager.moveItem(at: logFileURL, to: previousLogURL)
        fileManager.createFile(atPath: logFileURL.path, contents: nil)
        return true
    }

    private func logFileURL() -> URL? {
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }

        let directoryURL = appSupportURL
            .appendingPathComponent(applicationSupportFolder, isDirectory: true)
            .appendingPathComponent(logsFolder, isDirectory: true)

        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        } catch {
            fputs("Glance logger directory creation failed: \(error)\n", stderr)
            return nil
        }

        return directoryURL.appendingPathComponent(currentLogFile)
    }
}
