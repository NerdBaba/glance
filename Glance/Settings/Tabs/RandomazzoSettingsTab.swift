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
                        List(store.entries, selection: $selectedEntry) { entry in
                            HStack(spacing: 12) {
                                if store.isCorrupted(entry.name) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundStyle(.red)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.name)
                                        .font(.body)
                                    Text(entry.savedAt, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if let date = entry.lastRolled {
                                    Text(date, style: .relative)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("never")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                            .tag(entry as RandomazzoEntry?)
                        }
                        .frame(minHeight: 160)
                        .listStyle(.bordered(alternatesRowBackgrounds: true))
                    }
                }

                // MARK: - Action Buttons
                if !store.entries.isEmpty {
                    HStack(spacing: 8) {
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
        alert.informativeText = "Enter a name for this configuration (leave empty for auto-name):"
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        textField.stringValue = initial ?? ""
        alert.accessoryView = textField

        if alert.runModal() == .alertFirstButtonReturn {
            let name = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            completion(name)
        } else {
            completion(nil)
        }
    }
}
