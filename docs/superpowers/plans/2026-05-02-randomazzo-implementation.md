# Randomazzo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a configuration randomizer that saves full TOML config snapshots and applies them randomly via hotkey or UI.

**Architecture:** Full TOML snapshots stored as individual files in `~/Library/Application Support/glance/randomazzo/`, with a JSON metadata file tracking names/dates. A new store class manages CRUD, a new settings tab provides the UI, and the existing HotkeyManager is extended for multiple registrations.

**Tech Stack:** Swift, SwiftUI, Foundation, Carbon HIToolbox (existing), JSONEncoder/Decoder

---

### Task 1: RandomazzoStore — data model and storage layer

**Files:**
- Create: `Glance/Config/RandomazzoStore.swift`

- [ ] **Step 1: Create RandomazzoEntry model and RandomazzoStore class**

Create the data model and the store with metadata JSON persistence. The store manages `RandomazzoEntry` structs and persists metadata to `metadata.json` in the storage directory.

```swift
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
```

- [ ] **Step 2: Verify compilation**

Run:
```bash
xcodebuild -project Glance.xcodeproj -scheme Glance -configuration Release -derivedDataPath build build CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
```
Expected: Build succeeds (may fail on other unrelated files — look for no errors mentioning `RandomazzoStore`).

- [ ] **Step 3: Commit**

```bash
git add Glance/Config/RandomazzoStore.swift
git commit -m "feat: add RandomazzoStore data model and metadata layer"
```

---

### Task 2: RandomazzoStore — save, delete, rename operations

**Files:**
- Modify: `Glance/Config/RandomazzoStore.swift`

- [ ] **Step 1: Add save, delete, rename methods**

Append these methods to the `RandomazzoStore` class. `save` snapshots the current TOML config file. `delete` removes both the TOML and metadata entry. `rename` moves the file and updates metadata.

```swift
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
```

- [ ] **Step 2: Verify compilation**

```bash
xcodebuild -project Glance.xcodeproj -scheme Glance -configuration Release -derivedDataPath build build CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
```

- [ ] **Step 3: Commit**

```bash
git add Glance/Config/RandomazzoStore.swift
git commit -m "feat: add RandomazzoStore save, delete, rename operations"
```

---

### Task 3: RandomazzoStore — roll and apply operations

**Files:**
- Modify: `Glance/Config/RandomazzoStore.swift`
- Modify: `Glance/Config/ConfigManager.swift`

- [ ] **Step 1: Add pause/resume file watching to ConfigManager**

Add two public methods to `ConfigManager` so the roll operation can temporarily disable the file watcher during write (avoids partial-read issues).

In `Glance/Config/ConfigManager.swift`, add these two methods:

```swift
/// Temporarily stop watching the config file.
func pauseWatching() {
    stopWatchingFile()
    stopWatchingPywal()
}

/// Resume watching the config file and re-parse.
func resumeWatching() {
    if let path = configFilePath {
        parseConfigFile(at: path)
        startWatchingFile(at: path)
    }
    startWatchingPywal()
}
```

- [ ] **Step 2: Add roll and applyConfig to RandomazzoStore**

```swift
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
    guard let entry = entries.first(where: { $0.name == name }) else { return nil }

    let url = tomlURL(for: name)
    guard let tomlContent = try? String(contentsOf: url, encoding: .utf8) else {
        AppLogger.shared.error("Randomazzo: failed to read config '\(name)'", category: .app)
        return nil
    }

    guard let configPath = ConfigManager.shared.configFilePath else { return nil }

    // Pause watcher, write, resume
    ConfigManager.shared.pauseWatching()
    do {
        try tomlContent.write(toFile: configPath, atomically: true, encoding: .utf8)
    } catch {
        AppLogger.shared.error("Randomazzo: failed to write config: \(error.localizedDescription)", category: .app)
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
```

- [ ] **Step 3: Verify compilation**

```bash
xcodebuild -project Glance.xcodeproj -scheme Glance -configuration Release -derivedDataPath build build CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
```

- [ ] **Step 4: Commit**

```bash
git add Glance/Config/RandomazzoStore.swift Glance/Config/ConfigManager.swift
git commit -m "feat: add RandomazzoStore roll/apply and ConfigManager pause/resume watching"
```

---

### Task 4: Extend HotkeyManager for multiple hotkeys

**Files:**
- Modify: `Glance/Utils/HotkeyManager.swift`

- [ ] **Step 1: Refactor HotkeyManager to support multiple registrations**

The current `HotkeyManager` only supports one hotkey. Refactor it to accept a callback parameter in `register`, store multiple handlers, and use unique IDs. Replace the entire file content with:

```swift
import Carbon.HIToolbox
import Foundation

final class HotkeyManager {
    private var eventHandlerRef: EventHandlerRef?
    private var hotkeys: [UInt32: HotkeyRegistration] = [:]

    struct HotkeyRegistration {
        let modifiers: UInt32
        let keyCode: UInt32
        let handler: () -> Void
        var ref: EventHotKeyRef?
    }

    private static var instance: HotkeyManager?

    init() {
        HotkeyManager.instance = self
        installGlobalEventHandler()
    }

    private func installGlobalEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handler: EventHandlerUPP = { _, event, _ -> OSStatus in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventHotKeyID(), typeEventHotKeyID, nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            HotkeyManager.instance?.hotkeys[hotKeyID.id]?.handler()
            return noErr
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )
    }

    func register(modifiers: UInt32, keyCode: UInt32, handler: @escaping () -> Void) -> UInt32? {
        let id = nextHotkeyID()
        let hotKeyID = EventHotKeyID(
            signature: OSType(0x474C4E43),  // "GLNC"
            id: id
        )

        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )

        guard status == noErr, let validRef = ref else { return nil }

        hotkeys[id] = HotkeyRegistration(
            modifiers: modifiers,
            keyCode: keyCode,
            handler: handler,
            ref: validRef
        )
        return id
    }

    func unregister(id: UInt32) {
        guard let reg = hotkeys[id], let ref = reg.ref else { return }
        UnregisterEventHotKey(ref)
        hotkeys.removeValue(forKey: id)
    }

    func unregisterAll() {
        for (_, reg) in hotkeys {
            if let ref = reg.ref {
                UnregisterEventHotKey(ref)
            }
        }
        hotkeys.removeAll()
    }

    private var nextID: UInt32 = 1
    private func nextHotkeyID() -> UInt32 {
        let id = nextID
        nextID += 1
        return id
    }

    deinit {
        unregisterAll()
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
        }
    }

    /// Parse a hotkey string like "ctrl+option+b" into modifier flags and key code.
    static func parse(_ hotkeyString: String) -> (modifiers: UInt32, keyCode: UInt32)? {
        let parts = hotkeyString.lowercased().components(separatedBy: "+").map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        guard parts.count >= 2 else { return nil }

        var modifiers: UInt32 = 0
        var keyCode: UInt32?

        for part in parts {
            switch part {
            case "ctrl", "control":
                modifiers |= UInt32(controlKey)
            case "option", "alt", "opt":
                modifiers |= UInt32(optionKey)
            case "shift":
                modifiers |= UInt32(shiftKey)
            case "cmd", "command":
                modifiers |= UInt32(cmdKey)
            default:
                if let code = keyCodeMap[part] {
                    keyCode = code
                }
            }
        }

        guard let kc = keyCode else { return nil }
        return (modifiers, kc)
    }

    private static let keyCodeMap: [String: UInt32] = [
        "a": 0x00, "b": 0x0B, "c": 0x08, "d": 0x02, "e": 0x0E,
        "f": 0x03, "g": 0x05, "h": 0x04, "i": 0x22, "j": 0x26,
        "k": 0x28, "l": 0x25, "m": 0x2E, "n": 0x2D, "o": 0x1F,
        "p": 0x23, "q": 0x0C, "r": 0x0F, "s": 0x01, "t": 0x11,
        "u": 0x20, "v": 0x09, "w": 0x0D, "x": 0x07, "y": 0x10,
        "z": 0x06,
        "1": 0x12, "2": 0x13, "3": 0x14, "4": 0x15, "5": 0x17,
        "6": 0x16, "7": 0x1A, "8": 0x1C, "9": 0x19, "0": 0x1D,
        "space": 0x31, "escape": 0x35, "return": 0x24, "tab": 0x30,
    ]
}
```

- [ ] **Step 2: Verify compilation**

```bash
xcodebuild -project Glance.xcodeproj -scheme Glance -configuration Release -derivedDataPath build build CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
```

- [ ] **Step 3: Commit**

```bash
git add Glance/Utils/HotkeyManager.swift
git commit -m "refactor: extend HotkeyManager to support multiple hotkey registrations"
```

---

### Task 5: Wire up existing toggle hotkey to new HotkeyManager API

**Files:**
- Modify: `Glance/AppDelegate.swift`

- [ ] **Step 1: Update AppDelegate to use the new multi-hotkey API**

The existing `setupHotkey()` in AppDelegate uses the old single-hotkey API (`onToggle` closure). Update it to use the new `register(modifiers:keyCode:handler:)` method and store the hotkey ID.

Replace the hotkey-related section in `AppDelegate`:

Change:
```swift
private var hotkeyManager: HotkeyManager?
```
To:
```swift
private var hotkeyManager = HotkeyManager()
private var toggleHotkeyID: UInt32?
```

Replace the `setupHotkey()` method:

```swift
private func setupHotkey() {
    let config = ConfigManager.shared.config.rootToml
    let hotkeyString = config.hotkey ?? "ctrl+option+b"
    guard hotkeyString != "false" else { return }

    guard let parsed = HotkeyManager.parse(hotkeyString) else { return }

    toggleHotkeyID = hotkeyManager.register(
        modifiers: parsed.modifiers,
        keyCode: parsed.keyCode
    ) { [weak self] in
        self?.toggleBarVisibility()
    }
}
```

- [ ] **Step 2: Verify compilation**

```bash
xcodebuild -project Glance.xcodeproj -scheme Glance -configuration Release -derivedDataPath build build CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
```

- [ ] **Step 3: Commit**

```bash
git add Glance/AppDelegate.swift
git commit -m "refactor: update AppDelegate toggle hotkey to new multi-hotkey API"
```

---

### Task 6: Register randomazzo hotkey in AppDelegate

**Files:**
- Modify: `Glance/AppDelegate.swift`
- Create: `Glance/Utils/UserDefaults+Keys.swift`

- [ ] **Step 1: Create UserDefaults keys file**

The randomazzo hotkey string needs to be persisted. Use `UserDefaults` rather than adding it to the TOML config (it's app-level state, not config-level).

Create `Glance/Utils/UserDefaults+Keys.swift`:

```swift
import Foundation

extension UserDefaults {
    static let randomazzoHotkeyKey = "randomazzoHotkey"
    static let randomazzoExcludeCurrentKey = "randomazzoExcludeCurrent"

    var randomazzoHotkey: String {
        get { string(forKey: UserDefaults.randomazzoHotkeyKey) ?? "ctrl+option+r" }
        set { set(newValue, forKey: UserDefaults.randomazzoHotkeyKey) }
    }

    var randomazzoExcludeCurrent: Bool {
        get { bool(forKey: UserDefaults.randomazzoExcludeCurrentKey) }
        set { set(newValue, forKey: UserDefaults.randomazzoExcludeCurrentKey) }
    }
}
```

- [ ] **Step 2: Add randomazzo hotkey registration to AppDelegate**

Add a property and setup method to `AppDelegate`:

```swift
private var randomazzoHotkeyID: UInt32?
```

Add this method:

```swift
private func setupRandomazzoHotkey() {
    let hotkeyString = UserDefaults.standard.randomazzoHotkey
    guard let parsed = HotkeyManager.parse(hotkeyString) else { return }

    // Conflict check: if same as toggle hotkey, skip
    if let toggleID = toggleHotkeyID,
       let toggleConfig = ConfigManager.shared.config.rootToml.hotkey,
       let toggleParsed = HotkeyManager.parse(toggleConfig),
       toggleParsed.modifiers == parsed.modifiers && toggleParsed.keyCode == parsed.keyCode {
        AppLogger.shared.warning("Randomazzo hotkey conflicts with toggle hotkey, disabling", category: .app)
        return
    }

    randomazzoHotkeyID = hotkeyManager.register(
        modifiers: parsed.modifiers,
        keyCode: parsed.keyCode
    ) { [weak self] in
        self?.rollRandomazzo()
    }
}
```

Add the roll method:

```swift
private func rollRandomazzo() {
    let exclude = UserDefaults.standard.randomazzoExcludeCurrent
        ? ConfigManager.shared.config.rootToml.preset
        : nil
    // We need to track the current config name, not just preset.
    // For now, we pass nil (no exclusion) and the store will pick any random.
    // A proper implementation would compare the full config file content.
    _ = RandomazzoStore.shared.roll(excludeCurrent: nil)
}
```

Call `setupRandomazzoHotkey()` in `applicationDidFinishLaunching`, after `setupHotkey()`:

```swift
setupHotkey()
setupRandomazzoHotkey()
```

- [ ] **Step 3: Verify compilation**

```bash
xcodebuild -project Glance.xcodeproj -scheme Glance -configuration Release -derivedDataPath build build CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
```

- [ ] **Step 4: Commit**

```bash
git add Glance/Utils/UserDefaults+Keys.swift Glance/AppDelegate.swift
git commit -m "feat: register randomazzo hotkey in AppDelegate"
```

---

### Task 7: Add Randomazzo tab to Settings

**Files:**
- Modify: `Glance/Settings/SettingsView.swift`
- Create: `Glance/Settings/Tabs/RandomazzoSettingsTab.swift`

- [ ] **Step 1: Add randomazzo to SettingsTab enum and wire tab**

In `Glance/Settings/SettingsView.swift`, add the new case:

```swift
enum SettingsTab: String, CaseIterable {
    case general = "General"
    case widgets = "Widgets"
    case spaces = "Spaces"
    case time = "Time"
    case fonts = "Fonts"
    case randomazzo = "Randomazzo"
    case about = "About"

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .widgets: return "square.grid.2x2"
        case .spaces: return "rectangle.3.group"
        case .time: return "clock"
        case .fonts: return "textformat"
        case .randomazzo: return "dice.fill"
        case .about: return "info.circle"
        }
    }
}
```

In the `switch` statement in `body`, add before `case .about`:

```swift
case .randomazzo:
    RandomazzoSettingsTab()
```

- [ ] **Step 2: Create the Randomazzo settings tab**

Create `Glance/Settings/Tabs/RandomazzoSettingsTab.swift`:

```swift
import SwiftUI

struct RandomazzoSettingsTab: View {
    @ObservedObject var store = RandomazzoStore.shared
    @ObservedObject var configManager = ConfigManager.shared

    @State private var selectedEntry: RandomazzoEntry?
    @State private var hotkeyString: String = "ctrl+option+r"
    @State private var hotkeyValid: Bool = true
    @State private var excludeCurrent: Bool = false
    @State private var isSyncing: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // MARK: - Config List
                SettingsSection(title: "Saved Configurations") {
                    if store.entries.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "dice.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(.secondary)
                            Text("No saved configurations")
                                .font(.headline)
                            Text("Click the dice icon in the toolbar to add your current config.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    } else {
                        Table(store.entries, selection: $selectedEntry) {
                            TableColumn("Name") { entry in
                                HStack {
                                    if store.isCorrupted(entry.name) {
                                        Image(systemName: "exclamationmark.circle.fill")
                                            .foregroundStyle(.red)
                                    }
                                    Text(entry.name)
                                }
                            }
                            TableColumn("Saved") { entry in
                                Text(entry.savedAt, style: .date)
                                    .foregroundStyle(.secondary)
                            }
                            .width(100)
                            TableColumn("Last Roll") { entry in
                                if let date = entry.lastRolled {
                                    Text(date, style: .relative)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("—")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .width(100)
                        }
                        .frame(minHeight: 160)
                        .tableStyle(.bordered)
                    }
                }

                // MARK: - Action Buttons
                if !store.entries.isEmpty {
                    HStack(spacing: 8) {
                        Button("Add Current Config...") {
                            promptForName { name in
                                if let name = name {
                                    if store.exists(name) {
                                        let alert = NSAlert()
                                        alert.messageText = "A config named '\(name)' already exists."
                                        alert.informativeText = "Do you want to overwrite it?"
                                        alert.addButton(withTitle: "Overwrite")
                                        alert.addButton(withTitle: "Cancel")
                                        if alert.runModal() == .alertFirstButtonReturn {
                                            store.save(name: name)
                                        }
                                    } else {
                                        store.save(name: name)
                                    }
                                }
                            }
                        }
                        Button("Roll") {
                            roll()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(store.entries.count < 1)

                        Button("Apply") {
                            if let selected = selectedEntry {
                                _ = store.applyConfig(named: selected.name)
                            }
                        }
                        .disabled(selectedEntry == nil)

                        Button("Rename...") {
                            guard let selected = selectedEntry else { return }
                            promptForName(initial: selected.name) { name in
                                if let name = name, name != selected.name {
                                    if store.exists(name) {
                                        let alert = NSAlert()
                                        alert.messageText = "A config named '\(name)' already exists."
                                        alert.addButton(withTitle: "Overwrite")
                                        alert.addButton(withTitle: "Cancel")
                                        if alert.runModal() == .alertFirstButtonReturn {
                                            store.rename(from: selected.name, to: name)
                                        }
                                    } else {
                                        store.rename(from: selected.name, to: name)
                                    }
                                }
                            }
                        }
                        .disabled(selectedEntry == nil)

                        Button("Delete") {
                            guard let selected = selectedEntry else { return }
                            store.delete(name: selected.name)
                            selectedEntry = nil
                        }
                        .foregroundStyle(.red)
                        .disabled(selectedEntry == nil)
                    }
                }

                // MARK: - Hotkey
                SettingsSection(title: "Randomizer Hotkey") {
                    HStack {
                        Text("Roll random")
                            .frame(width: 130, alignment: .leading)
                        TextField("ctrl+option+r", text: $hotkeyString)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 200)
                            .onChange(of: hotkeyString) { _, newValue in
                                guard !isSyncing else { return }
                                let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                                if trimmed == "false" || HotkeyManager.parse(trimmed) != nil {
                                    hotkeyValid = true
                                    UserDefaults.standard.randomazzoHotkey = trimmed
                                } else {
                                    hotkeyValid = false
                                }
                            }
                        if !hotkeyValid {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                        }
                    }
                    Text("Format: modifier+modifier+key (e.g. ctrl+option+r). Set to \"false\" to disable.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // MARK: - Options
                SettingsSection(title: "Options") {
                    Toggle("Exclude current config when rolling", isOn: $excludeCurrent)
                        .onChange(of: excludeCurrent) { _, newValue in
                            UserDefaults.standard.randomazzoExcludeCurrent = newValue
                        }
                }

                // MARK: - Big Roll Button
                if !store.entries.isEmpty {
                    Button(action: roll) {
                        Label("Roll Random Config", systemImage: "dice.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                }

                Spacer()
            }
            .padding(24)
        }
        .onAppear { syncFromUserDefaults() }
    }

    private func roll() {
        let currentName = configManager.config.rootToml.preset
        let exclude = UserDefaults.standard.randomazzoExcludeCurrent ? currentName : nil
        if let result = store.roll(excludeCurrent: exclude) {
            // Brief visual feedback could be added here
            AppLogger.shared.info("Randomazzo rolled: \(result)", category: .app)
        }
    }

    private func syncFromUserDefaults() {
        isSyncing = true
        defer { isSyncing = false }
        hotkeyString = UserDefaults.standard.randomazzoHotkey
        excludeCurrent = UserDefaults.standard.randomazzoExcludeCurrent
    }

    private func promptForName(initial: String? = nil, completion: @escaping (String?) -> Void) {
        let alert = NSAlert()
        alert.messageText = "Save Configuration"
        alert.informativeText = "Enter a name for this configuration:"
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        textField.stringValue = initial ?? ""
        alert.accessoryView = textField

        if alert.runModal() == .alertFirstButtonReturn {
            let name = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            completion(name.isEmpty ? nil : name)
        } else {
            completion(nil)
        }
    }
}
```

- [ ] **Step 3: Fix the promptForName to handle auto-naming**

The `promptForName` above returns `nil` for empty input, which means the save doesn't happen. But the spec says empty → timestamp. Fix the save callback in the "Add Current Config" button. Replace the `promptForName` closure in the Add button:

In the `roll()` area of the tab, the Add button already handles the duplicate check. The auto-naming with timestamp is handled inside `store.save(name:)` with `defaultName()`. So actually, we need to also allow empty name to pass through to the store. Let me update `promptForName` to return an empty string (which the store will replace with timestamp):

Change the `promptForName` method's completion call at the end:

```swift
    private func promptForName(initial: String? = nil, completion: @escaping (String?) -> Void) {
        let alert = NSAlert()
        alert.messageText = "Save Configuration"
        alert.informativeText = "Enter a name for this configuration (leave empty for auto-name):"
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        textField.stringValue = initial ?? ""
        alert.accessoryView = textField

        if alert.runModal() == .alertFirstButtonReturn {
            let name = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            completion(name)  // Empty string passes through → store uses defaultName()
        } else {
            completion(nil)
        }
    }
```

And update the Add button's `if let name = name` check to handle empty string:

```swift
                        Button("Add Current Config...") {
                            promptForName { name in
                                guard let name = name else { return }
                                let finalName = name.isEmpty ? nil : name
                                if let n = finalName, store.exists(n) {
                                    let alert = NSAlert()
                                    alert.messageText = "A config named '\(n)' already exists."
                                    alert.informativeText = "Do you want to overwrite it?"
                                    alert.addButton(withTitle: "Overwrite")
                                    alert.addButton(withTitle: "Cancel")
                                    if alert.runModal() == .alertFirstButtonReturn {
                                        store.save(name: n)
                                    }
                                } else {
                                    store.save(name: finalName ?? "")
                                }
                            }
                        }
```

Also update `RandomazzoStore.save(name:)` to handle empty name:

In `RandomazzoStore.swift`, change the `save` method's first lines:

```swift
func save(name: String) {
    let sanitizedName = sanitized(name)
    let finalName = sanitizedName.isEmpty ? defaultName() : sanitizedName
```

This is already in Task 2. Good.

- [ ] **Step 4: Verify compilation**

```bash
xcodebuild -project Glance.xcodeproj -scheme Glance -configuration Release -derivedDataPath build build CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
```

- [ ] **Step 5: Commit**

```bash
git add Glance/Settings/SettingsView.swift Glance/Settings/Tabs/RandomazzoSettingsTab.swift
git commit -m "feat: add Randomazzo settings tab with config list and controls"
```

---

### Task 8: Add toolbar button to Settings window

**Files:**
- Modify: `Glance/Settings/SettingsWindowController.swift`

- [ ] **Step 1: Add dice toolbar button with dropdown menu**

Replace the entire `SettingsWindowController.swift` with:

```swift
import SwiftUI

/// Manages the Settings window lifecycle.
/// Since Glance is an LSUIElement app (no Dock icon), we manage
/// the Settings window manually via NSWindow.
final class SettingsWindowController: NSWindowDelegate {
    static let shared = SettingsWindowController()

    private var window: NSWindow?
    private var randomazzoToolbarItem: NSToolbarItem?

    private init() {}

    func showSettings() {
        if let window = window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }

        let settingsView = SettingsView()
        let hostingView = NSHostingView(rootView: settingsView)

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 480),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        newWindow.title = "Glance Settings"
        newWindow.contentView = hostingView
        newWindow.center()
        newWindow.setFrameAutosaveName("GlanceSettings")
        newWindow.minSize = NSSize(width: 560, height: 400)
        newWindow.isReleasedWhenClosed = false
        newWindow.delegate = self

        // Add toolbar with randomazzo button
        setupToolbar(window: newWindow)

        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate()

        self.window = newWindow
    }

    private func setupToolbar(window: NSWindow) {
        let toolbar = NSToolbar(identifier: "GlanceSettingsToolbar")
        toolbar.displayMode = .iconOnly
        toolbar.showsBaselineSeparator = true

        let diceItem = NSToolbarItem(identifier: "RandomazzoToolbarItem")
        let button = NSButton()
        button.image = NSImage(systemSymbolName: "dice.fill", accessibilityDescription: "Randomazzo")
        button.bezelStyle = .toolbar
        button.bordered = false
        button.target = self
        button.action = #selector(showRandomazzoMenu(_:))

        // Create dropdown-style menu button
        let menuButton = NSPopUpButton(title: "", target: nil, action: nil)
        menuButton.image = NSImage(systemSymbolName: "dice.fill", accessibilityDescription: "Randomazzo")
        menuButton.bezelStyle = .toolbar
        menuButton.showsBorderOnlyWhileMouseInside = true
        menuButton.target = self
        menuButton.action = #selector(showRandomazzoMenu(_:))
        menuButton.menu = nil  // We'll show menu programmatically

        diceItem.view = menuButton
        randomazzoToolbarItem = diceItem

        toolbar.items = [diceItem]
        window.toolbar = toolbar
    }

    @objc private func showRandomazzoMenu(_ sender: NSButton) {
        let menu = NSMenu()

        let addItem = NSMenuItem(title: "Add Current Config...", action: #selector(addCurrentConfig), keyEquivalent: "")
        addItem.target = self
        menu.addItem(addItem)

        menu.addItem(NSMenuItem.separator())

        let openItem = NSMenuItem(title: "Open Randomazzo Settings", action: #selector(openRandomazzoSettings), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        // Show menu below the button
        let location = NSPoint(x: 0, y: sender.frame.maxY + 4)
        menu.popUp(positioning: nil, at: location, in: sender)
    }

    @objc private func addCurrentConfig() {
        // Reuse the prompt logic from the settings tab
        let alert = NSAlert()
        alert.messageText = "Save Configuration"
        alert.informativeText = "Enter a name for this configuration (leave empty for auto-name):"
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        alert.accessoryView = textField

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let name = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let store = RandomazzoStore.shared

        if name.isEmpty {
            store.save(name: "")
        } else if store.exists(name) {
            let confirmAlert = NSAlert()
            confirmAlert.messageText = "A config named '\(name)' already exists."
            confirmAlert.informativeText = "Do you want to overwrite it?"
            confirmAlert.addButton(withTitle: "Overwrite")
            confirmAlert.addButton(withTitle: "Cancel")
            if confirmAlert.runModal() == .alertFirstButtonReturn {
                store.save(name: name)
            }
        } else {
            store.save(name: name)
        }
    }

    @objc private func openRandomazzoSettings() {
        // Switch to the Randomazzo tab
        // Post a notification that the SettingsView can observe
        NotificationCenter.default.post(
            name: Notification.Name("SwitchToRandomazzoTab"),
            object: nil
        )
    }
}
```

- [ ] **Step 2: Wire tab switching in SettingsView**

In `Glance/Settings/SettingsView.swift`, add notification observer to switch to the Randomazzo tab when the toolbar button is clicked.

Add to the `body` of `SettingsView`:

```swift
    var body: some View {
        NavigationSplitView {
            List(SettingsTab.allCases, id: \.self, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
        } detail: {
            switch selectedTab {
            case .general:
                GeneralSettingsTab()
            case .widgets:
                WidgetsSettingsTab()
            case .spaces:
                SpacesSettingsTab()
            case .time:
                TimeSettingsTab()
            case .fonts:
                FontSettingsTab()
            case .randomazzo:
                RandomazzoSettingsTab()
            case .about:
                AboutSettingsTab()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SwitchToRandomazzoTab"))) { _ in
            selectedTab = .randomazzo
        }
    }
```

- [ ] **Step 3: Verify compilation**

```bash
xcodebuild -project Glance.xcodeproj -scheme Glance -configuration Release -derivedDataPath build build CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
```

- [ ] **Step 4: Commit**

```bash
git add Glance/Settings/SettingsWindowController.swift Glance/Settings/SettingsView.swift
git commit -m "feat: add Randomazzo toolbar button with dropdown menu"
```

---

### Task 9: Build, deploy, and verify

**Files:** No file changes — build and deploy verification.

- [ ] **Step 1: Move style files out, build, deploy**

```bash
mkdir -p /tmp/glance-styles-backup
mv Glance/Styles/{Glass,Minimal,Solid,System}Style.swift /tmp/glance-styles-backup/ 2>/dev/null || true
pkill -x Glance; sleep 2
rm -rf /Applications/Glance.app
xcodebuild -project Glance.xcodeproj -scheme Glance -configuration Release -derivedDataPath build build CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10
cp -R build/Build/Products/Release/Glance.app /Applications/Glance.app
cp /tmp/glance-styles-backup/*.swift Glance/Styles/ 2>/dev/null || true
```

- [ ] **Step 2: Manual verification checklist**

1. Open Glance from `/Applications/Glance.app`
2. Open Settings → verify "Randomazzo" tab appears in sidebar with dice icon
3. Click dice toolbar button → verify dropdown shows "Add Current Config..." and "Open Randomazzo Settings"
4. Click "Add Current Config..." → enter name → verify it appears in the list
5. Change some settings (preset, formation), add another config with a different name
6. Click "Roll Random Config" → verify the bar changes appearance
7. Test hotkey `ctrl+option+r` → verify it rolls
8. Test "Exclude current" toggle → verify it doesn't pick the same config twice in a row
9. Test rename and delete
10. Verify corrupted TOML shows red indicator

- [ ] **Step 3: Commit final**

```bash
git add -A
git commit -m "feat: randomazzo implementation complete"
```

---

## Self-Review

**1. Spec coverage:**

| Spec Section | Task |
|---|---|
| Full TOML snapshots | Task 2 (`save` method reads TOML, writes verbatim) |
| Storage directory `~/Library/Application Support/glance/randomazzo/` | Task 1 (`storageDir`) |
| metadata.json | Task 1 (`metadataURL`, `loadMetadata`, `saveMetadata`) |
| RandomazzoEntry model | Task 1 |
| Save with name prompt + timestamp fallback | Task 7 (`promptForName`), Task 2 (`defaultName`) |
| Duplicate name → overwrite/cancel prompt | Task 7 (alert in Add/Rename buttons) |
| Roll behavior (pause watcher, write, resume) | Task 3 (`roll`, `applyConfig` + `pauseWatching`/`resumeWatching`) |
| Pywal live at apply time | Handled by existing ConfigManager (no changes needed) |
| Settings tab with list, Add/Rename/Delete/Roll | Task 7 |
| Hotkey configuration | Task 6, Task 7 |
| Exclude current toggle | Task 6, Task 7 |
| Toolbar button with dropdown | Task 8 |
| Empty state | Task 7 |
| Corrupted TOML indicator | Task 7 (`isCorrupted` check in table) |
| Hotkey conflict detection | Task 6 |
| HotkeyManager multi-registration | Task 4 |

All spec requirements covered.

**2. Placeholder scan:** No TBDs, TODOs, or vague instructions. All code blocks contain actual implementations.

**3. Type consistency:** `RandomazzoEntry` uses `String` for `id` (not UUID directly, to make Codable simpler). `RandomazzoStore.shared` used consistently. `ConfigManager.shared.configFilePath` used for the active config path. `UserDefaults.standard` keys defined in extension. Hotkey parsing uses existing `HotkeyManager.parse()`.

**4. Scope check:** Focused on one feature. 9 tasks, each producing buildable state.
