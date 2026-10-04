import Foundation
import TOMLDecoder

/// A single saved configuration in the randomazzo container.
struct RandomazzoEntry: Equatable, Hashable, Codable, Identifiable {
  var name: String
  var savedAt: Date
  var lastRolled: Date?
  /// Optional so metadata saved by older versions still decodes.
  var iconSeed: UInt32?

  var id: String { name }

  init(name: String, savedAt: Date = Date(), lastRolled: Date? = nil) {
    self.name = name
    self.savedAt = savedAt
    self.lastRolled = lastRolled
    self.iconSeed = UInt32.random(in: .min ... .max)
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
    seedBundledPolybarPresets()
  }

  // MARK: - Metadata

  private func loadMetadata() {
    guard let data = try? Data(contentsOf: metadataURL),
      let metadata = try? JSONDecoder().decode(RandomazzoMetadata.self, from: data)
    else {
      entries = []
      return
    }
    entries = metadata.entries
    var assignedIcons = false
    for index in entries.indices where entries[index].iconSeed == nil {
      entries[index].iconSeed = UInt32.random(in: .min ... .max)
      assignedIcons = true
    }
    if assignedIcons { saveMetadata() }
  }

  private func saveMetadata() {
    let metadata = RandomazzoMetadata(entries: entries)
    if let data = try? JSONEncoder().encode(metadata) {
      try? data.write(to: metadataURL, options: .atomic)
    }
  }

  /// Import the bundled Polybar-inspired themes as ordinary Randomazzo
  /// snapshots. Existing entries and files are never overwritten.
  private func seedBundledPolybarPresets() {
    guard let resourceURL = Bundle.main.resourceURL else { return }
    let presetsURL = resourceURL.appendingPathComponent("PolybarThemeDrafts", isDirectory: true)
    guard
      let files = try? fm.contentsOfDirectory(
        at: presetsURL,
        includingPropertiesForKeys: nil
      )
    else { return }

    var importedAny = false
    for sourceURL
      in files
      .filter({ $0.pathExtension.lowercased() == "toml" })
      .sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
    {
      let themeName = sourceURL.deletingPathExtension().lastPathComponent
      let entryName = "Polybar — \(themeName)"
      let destinationURL = tomlURL(for: entryName)

      guard !entries.contains(where: { $0.name == entryName }),
        !fm.fileExists(atPath: destinationURL.path),
        let data = try? Data(contentsOf: sourceURL),
        let content = String(data: data, encoding: .utf8)
      else {
        continue
      }

      let decoder = TOMLDecoder()
      guard (try? decoder.decode(RootToml.self, from: content)) != nil else {
        AppLogger.shared.error(
          "Randomazzo: bundled Polybar preset '\(themeName)' is invalid TOML",
          category: .app
        )
        continue
      }

      do {
        try data.write(to: destinationURL, options: .atomic)
        entries.append(RandomazzoEntry(name: entryName))
        importedAny = true
        AppLogger.shared.info(
          "Randomazzo: imported Polybar preset '\(themeName)'",
          category: .app
        )
      } catch {
        AppLogger.shared.error(
          "Randomazzo: failed to import Polybar preset '\(themeName)': \(error.localizedDescription)",
          category: .app
        )
      }
    }

    if importedAny {
      saveMetadata()
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

  // MARK: - Preset icons

  func shuffleIcon(for name: String) {
    guard let index = entries.firstIndex(where: { $0.name == name }) else { return }
    entries[index].iconSeed = nextIconSeed(after: entries[index].iconSeed)
    saveMetadata()
  }

  func shuffleAllIcons() {
    for index in entries.indices {
      entries[index].iconSeed = nextIconSeed(after: entries[index].iconSeed)
    }
    saveMetadata()
  }

  private func nextIconSeed(after current: UInt32?) -> UInt32 {
    var seed = UInt32.random(in: .min ... .max)
    // A shuffle always changes the visible character, not just its tint.
    while seed % 32 == (current ?? 0) % 32 {
      seed = UInt32.random(in: .min ... .max)
    }
    return seed
  }

  // MARK: - Save

  /// Snapshot the current config into the randomazzo container.
  func save(name: String) {
    let sanitizedName = sanitized(name)
    let finalName = sanitizedName.isEmpty ? defaultName() : sanitizedName

    // Read current config file
    guard let configPath = ConfigManager.shared.configFilePath,
      let tomlContent = try? String(contentsOfFile: configPath, encoding: .utf8)
    else {
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
    formatter.dateFormat = "yyyy-MM-dd HH-mm"
    return formatter.string(from: Date())
  }

  // MARK: - Roll / Apply

  /// Pick a random config and apply it. Returns the name of the applied config.
  func roll(excludeCurrent: String?) -> String? {
    var pool = entries
    if let exclude = excludeCurrent {
      pool = pool.filter { $0.name != exclude }
    }
    guard !pool.isEmpty else { return nil }

    let chosen = pool.randomElement()!
    return applyConfig(named: chosen.name)
  }

  /// Apply a specific config by name. Returns the name on success.
  func applyConfig(named name: String) -> String? {
    AppLogger.shared.info("applyConfig called for: '\(name)'", category: .app)
    guard let entry = entries.first(where: { $0.name == name }) else {
      AppLogger.shared.error("Randomazzo: entry '\(name)' not found in entries", category: .app)
      return nil
    }

    let url = tomlURL(for: name)
    AppLogger.shared.info("TOML URL: \(url.path)", category: .app)
    guard let tomlContent = try? String(contentsOf: url, encoding: .utf8) else {
      AppLogger.shared.error("Randomazzo: failed to read config '\(name)'", category: .app)
      return nil
    }

    guard let configPath = ConfigManager.shared.configFilePath else {
      AppLogger.shared.error("Randomazzo: configFilePath is nil", category: .app)
      return nil
    }
    AppLogger.shared.info("Writing to config path: \(configPath)", category: .app)

    // Pause watcher, write, resume
    ConfigManager.shared.pauseWatching()
    do {
      try tomlContent.write(toFile: configPath, atomically: true, encoding: .utf8)
    } catch {
      AppLogger.shared.error(
        "Randomazzo: failed to write config: \(error.localizedDescription)", category: .app)
      ConfigManager.shared.resumeWatching()
      return nil
    }
    ConfigManager.shared.resumeWatching()

    // Update lastRolled
    if let index = entries.firstIndex(where: { $0.name == name }) {
      entries[index].lastRolled = Date()
      saveMetadata()
    }

    return name
  }

  /// Check if a TOML file is valid (can be parsed).
  func isCorrupted(_ name: String) -> Bool {
    let url = tomlURL(for: name)
    guard let content = try? String(contentsOf: url, encoding: .utf8) else { return true }
    let decoder = TOMLDecoder()
    return (try? decoder.decode(RootToml.self, from: content)) == nil
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
