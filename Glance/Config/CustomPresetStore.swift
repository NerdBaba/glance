import Foundation

/// Manages user-created presets stored as TOML files in Application Support.
final class CustomPresetStore: ObservableObject {
    static let shared = CustomPresetStore()

    @Published private(set) var presetNames: [String] = []

    private let presetsDir: URL
    private let fm = FileManager.default

    private init() {
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        presetsDir = appSupport.appendingPathComponent("glance/presets", isDirectory: true)
        try? fm.createDirectory(at: presetsDir, withIntermediateDirectories: true)
        reload()
    }

    /// Sanitize a preset name to prevent path traversal.
    /// Strips path separators, takes only the filename component, and rejects empty results.
    private func safeFileURL(for name: String) -> URL? {
        let sanitized = (name as NSString).lastPathComponent
            .replacingOccurrences(of: "/", with: "")
            .replacingOccurrences(of: "\0", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitized.isEmpty, sanitized != ".", sanitized != ".." else { return nil }

        let fileURL = presetsDir.appendingPathComponent("\(sanitized).toml")
        // Verify resolved path is inside presetsDir
        guard fileURL.standardizedFileURL.path.hasPrefix(presetsDir.standardizedFileURL.path) else {
            return nil
        }
        return fileURL
    }

    func reload() {
        let files = (try? fm.contentsOfDirectory(at: presetsDir, includingPropertiesForKeys: nil)) ?? []
        presetNames = files
            .filter { $0.pathExtension == "toml" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
    }

    /// Save current appearance overrides as a named custom preset.
    func save(name: String, overrides: [String: String]) {
        guard let file = safeFileURL(for: name) else { return }
        let lines = overrides.sorted(by: { $0.key < $1.key }).map { key, value in
            "\(key) = \(value)"
        }
        let content = lines.joined(separator: "\n") + "\n"
        try? content.write(to: file, atomically: true, encoding: .utf8)
        reload()
    }

    /// Load a custom preset's overrides as key-value pairs.
    func load(name: String) -> [String: String]? {
        guard let file = safeFileURL(for: name) else { return nil }
        guard let content = try? String(contentsOf: file, encoding: .utf8) else { return nil }
        var result: [String: String] = [:]
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            let parts = trimmed.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            result[key] = value
        }
        return result
    }

    func delete(name: String) {
        guard let file = safeFileURL(for: name) else { return }
        try? fm.removeItem(at: file)
        reload()
    }
}
