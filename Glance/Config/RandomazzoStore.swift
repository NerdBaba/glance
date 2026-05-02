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
        try? JSONEncoder().encode(metadata).write(to: metadataURL)
    }

    // MARK: - Path helpers

    private func tomlURL(for name: String) -> URL {
        storageDir.appendingPathComponent("\(sanitized(name)).toml")
    }

    private func sanitized(_ name: String) -> String {
        (name as NSString).lastPathComponent
            .replacingOccurrences(of: "/", with: "")
            .replacingOccurrences(of: "\0", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Existence check

    func exists(_ name: String) -> Bool {
        entries.contains { $0.name == name }
    }

    func tomlExists(_ name: String) -> Bool {
        fm.fileExists(atPath: tomlURL(for: name).path)
    }
}
