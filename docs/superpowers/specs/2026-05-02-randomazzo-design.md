# Randomazzo — Configuration Randomizer

## Summary

Randomazzo is a configuration container and randomizer for Glance. Users save full TOML config snapshots into a "randomazzo" container, then trigger a random selection to apply any saved config. Pywal colors are always fetched live at apply time (not snapshotted).

## Approach

**Full TOML Snapshots** — each saved config is a complete `.toml` file stored in `~/Library/Application Support/glance/randomazzo/`. On roll, the selected file is written to the active config path, and the existing file watcher in `ConfigManager` picks it up.

## Architecture

### New Files

| File | Purpose |
|------|---------|
| `Glance/Config/RandomazzoStore.swift` | CRUD for saved configs, random selection, TOML file I/O |
| `Glance/Settings/Tabs/RandomazzoSettingsTab.swift` | Settings tab with config list, roll, rename, delete |
| `Glance/Settings/Components/RandomazzoHotkeyField.swift` | Hotkey input field (reuses existing HotkeyManager pattern) |

### Modified Files

| File | Change |
|------|--------|
| `Glance/Settings/SettingsView.swift` | Add `randomazzo` case to `SettingsTab` enum, wire up new tab |
| `Glance/Settings/SettingsWindowController.swift` | Add toolbar button (dice icon) with dropdown menu |
| `Glance/Utils/HotkeyManager.swift` | Support multiple hotkey registrations (currently only supports one) |
| `Glance/AppDelegate.swift` | Register randomazzo hotkey on launch |

### Data Model

```swift
struct RandomazzoEntry: Identifiable, Equatable {
    let id: UUID
    var name: String
    var savedAt: Date
    var lastRolled: Date?
}

final class RandomazzoStore: ObservableObject {
    @Published private(set) var entries: [RandomazzoEntry]

    var storageDir: URL  // ~/Library/Application Support/glance/randomazzo/

    func save(name: String, prompt: Bool = true)       // snapshot current config
    func delete(name: String)                           // remove file + entry
    func rename(from oldName: String, to newName: String)
    func roll(excludeCurrent: String?) -> String?       // pick random, apply, return name
    func applyConfig(named: String) -> String?          // apply specific config, return name
    func exists(_ name: String) -> Bool
    func isCorrupted(_ name: String) -> Bool            // TOML parse check
}
```

## Storage

- **Directory:** `~/Library/Application Support/glance/randomazzo/`
- **Format:** Complete TOML files (`<name>.toml`)
- **Metadata:** A `metadata.json` file in the same directory tracking `name`, `savedAt`, `lastRolled` for each entry (separate from TOML for clean reads)

### Metadata JSON

```json
{
  "entries": [
    {
      "name": "Dark Setup",
      "savedAt": "2026-05-02T14:30:00Z",
      "lastRolled": "2026-05-02T18:45:00Z"
    }
  ]
}
```

## Snapshot Behavior

1. Read the current config file (`~/.glance-config.toml`) as raw text
2. Write the content verbatim to `<storageDir>/<name>.toml`
3. Create/update the metadata entry with `savedAt` timestamp

**Pywal:** The TOML is saved as-is. If it contains `use-pywal = true`, that flag is preserved. Pywal colors themselves are NOT saved — they're always fetched live from `~/.cache/wal/colors` at apply time by the existing `ConfigManager` mechanism.

## Roll Behavior

1. Pick a random entry from `entries` (optionally excluding current config name)
2. Read the TOML file content
3. Briefly pause the `ConfigManager` file watcher (to avoid partial-read during write)
4. Write the TOML content to the active config path (`~/.glance-config.toml`)
5. Resume the file watcher — it detects the change and re-parses
6. If `use-pywal = true`, `ConfigManager` reads current pywal colors and applies them
7. SwiftUI re-renders with the new config
8. Update `lastRolled` in metadata

## Direct Apply (Double-Click)

Double-clicking a config row in the list applies it immediately (same flow as roll, but user-selected instead of random).

## UI Design

### Settings Tab

New tab in sidebar: `Randomazzo` (icon: `dice.fill`)

Layout:
- **Top:** Table of saved configs with columns: Name, Saved date, Last Roll
- **Middle:** Action buttons: `[+ Add] [Rename] [Delete] [Roll]`
- **Bottom section:**
  - Randomizer hotkey configuration (same pattern as existing toggle hotkey)
  - Large "Roll Random Config" button
  - Toggle: "Exclude current config when rolling"

### Toolbar Button

Dice icon (`dice.fill`) in the Settings window toolbar:
- Click → dropdown menu:
  - **"Add Current Config..."** → prompts for name → saves
  - **"Open Randomazzo Settings"** → switches to the Randomazzo tab

### Empty State

When no configs saved:
- Centered message: "No saved configurations"
- Subtitle: "Click the dice icon in the toolbar to add your current config."
- Roll button disabled

### Naming

- On save: prompt dialog for name
- If name left empty → auto-name with timestamp (e.g., `2026-05-02 17:30`)
- Duplicate name → alert: "A config named 'X' already exists. Overwrite or cancel?"

## Hotkey

- Default: `ctrl+option+r`
- Configurable in the Randomazzo settings tab
- Same parsing/validation as the existing toggle hotkey
- Conflict detection: if same as toggle hotkey, show warning and disable

## Error Handling

| Scenario | Behavior |
|----------|----------|
| No configs saved | Roll button disabled, empty state shown |
| Corrupted TOML file | Skip during roll, log warning, show red indicator in list |
| Config file write fails | Show alert, don't update store state |
| Pywal enabled but colors file missing | Existing ConfigManager handles gracefully (nil pywal → preset defaults) |
| Hotkey conflict with toggle | Show warning, disable randomizer hotkey |
| Single config + exclude current on | Roll button disabled, tooltip explains why |

## Widget Order & Settings

The snapshot captures the entire TOML, so widget order, widget settings, formation, appearance, fonts — everything is restored exactly as saved. The Settings UI state syncs from the loaded config via the existing `syncFromConfig()` mechanism.

## Exclusions from Design

- Multi-monitor support (not in scope)
- Partial config snapshots (always full TOML)
- Config diff/merge (snapshots are atomic)
- Visual previews of configs (future enhancement)
