import Foundation

/// A single saved configuration in the randomazzo container.
struct RandomazzoEntry: Identifiable, Equatable, Codable {
    var id: String
    var name: String
    var savedAt: Date
    var lastRolled: Date?

    init(id: String = UUID().uuidString, name: String, savedAt: Date = Date(), lastRolled: Date? = nil) {
        self.id = id
        self.name = name
        self.savedAt = savedAt
        self.lastRolled = lastRolled
    }
}

/// Metadata container for JSON serialization.
private struct RandomazzoMetadata: Codable {
    var entries: [RandomazzoEntry]
}

/// Manages the randomazzo configuration container.
/// Stores full TOML snapshots and a metadata.json for tracking.
final class RandomazzoStore: ObservableObject {
    static let shared = RandomazzoStore()

    @Published private(set) var entries: [RandomazzoEntry] = []

    let storageDir: URL
    private let metadataURL: URL
    private let fm = FileManager.default

    private init() {
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        storageDir = appSupport.appendingPathComponent("glance/randomazzo", isDirectory: true)
        metadataURL = storageDir.appendingPathComponent("metadata.json")

        try? fm.createDirectory(at: storageDir, withIntermediateDirectories: true)
        loadMetadata()
    }

    // MARK: - Metadata

    private func loadMetadata() {
        guard let data = try? Data(contentsOf: metadataURL),
              let metadata = try? JSONDecoder().decode(RandomazzoMetadata.self, from: data) else {
            entries = []
            return
        }
        entries = metadata.entries
    }

    private func saveMetadata() {
        let metadata = RandomazzoMetadata(entries: entries)
        if let data = try? JSONEncoder().encode(metadata) {
            try? data.write(to: metadataURL, options: .atomic)
        }
    }

    // MARK: - Path helpers

    private func tomlURL(for name: String) -> URL {
        storageDir.appendingPathComponent("\(sanitized(name)).toml")
    }

    private func sanitized(_ name: String) -> String {
        let s = (name as NSString).lastPathComponent
            .replacingOccurrences(of: "/", with: "")
            .replacingOccurrences(of: "\0", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty, s != ".", s != ".." else { return "_" }
        return s
    }

    // MARK: - Existence check

    func exists(_ name: String) -> Bool {
        entries.contains { $0.name == name }
    }

    func tomlExists(_ name: String) -> Bool {
        fm.fileExists(atPath: tomlURL(for: name).path)
    }

    // MARK: - Save

    /// Snapshot the current config into the randomazzo container.
    func save(name: String) {
        let sanitizedName = sanitized(name)
        let finalName = sanitizedName.isEmpty ? defaultName() : sanitizedName

        // Read current config file
        guard let configPath = ConfigManager.shared.configFilePath,
              let tomlContent = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            AppLogger.shared.error("Randomazzo: no config file to save", category: .app)
            return
        }

        // Write TOML snapshot
        let url = tomlURL(for: finalName)
        try? tomlContent.write(to: url, atomically: true, encoding: .utf8)

        // Upsert metadata entry
        if let existingIndex = entries.firstIndex(where: { $0.name == finalName }) {
            entries[existingIndex].savedAt = Date()
        } else {
            entries.append(RandomazzoEntry(name: finalName))
        }
        saveMetadata()
    }

    private func defaultName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: Date())
    }

    // MARK: - Delete

    func delete(name: String) {
        // Remove TOML file
        let url = tomlURL(for: name)
        try? fm.removeItem(at: url)

        // Remove metadata entry
        entries.removeAll { $0.name == name }
        saveMetadata()
    }

    // MARK: - Rename

    func rename(from oldName: String, to newName: String) {
        let sanitizedName = sanitized(newName)
        guard !sanitizedName.isEmpty else { return }

        // Rename TOML file
        let oldURL = tomlURL(for: oldName)
        let newURL = tomlURL(for: sanitizedName)
        try? fm.moveItem(at: oldURL, to: newURL)

        // Update metadata
        if let index = entries.firstIndex(where: { $0.name == oldName }) {
            entries[index].name = sanitizedName
        }
        saveMetadata()
    }
}
