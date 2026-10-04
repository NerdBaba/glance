import SwiftUI

struct RandomazzoSettingsTab: View {
  @ObservedObject var store = RandomazzoStore.shared
  @ObservedObject var configManager = ConfigManager.shared

  @State private var selectedName: String?
  @State private var searchText = ""
  @State private var sortOrder: PresetSort = .newest
  @State private var unavailableNames: Set<String> = []
  @State private var hotkeyString = "ctrl+option+r"
  @State private var hotkeyValid = true
  @State private var excludeCurrent = false
  @State private var isSyncing = false

  private enum PresetSort: String, CaseIterable, Identifiable {
    case newest = "Newest first"
    case name = "Name"
    case lastUsed = "Last used"
    var id: Self { self }
  }

  private struct AvailabilityKey: Equatable {
    let name: String
    let savedAt: Date
  }

  private var availabilityKeys: [AvailabilityKey] {
    store.entries.map { AvailabilityKey(name: $0.name, savedAt: $0.savedAt) }
  }

  private var visibleEntries: [RandomazzoEntry] {
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    return store.entries
      .filter { query.isEmpty || $0.name.localizedStandardContains(query) }
      .sorted { lhs, rhs in
        switch sortOrder {
        case .newest:
          if lhs.savedAt != rhs.savedAt { return lhs.savedAt > rhs.savedAt }
        case .lastUsed:
          let left = lhs.lastRolled ?? .distantPast
          let right = rhs.lastRolled ?? .distantPast
          if left != right { return left > right }
        case .name:
          break
        }
        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
      }
  }

  private var presetCount: String {
    if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return "\(store.entries.count) \(store.entries.count == 1 ? "preset" : "presets")"
    }
    return "\(visibleEntries.count) of \(store.entries.count) presets"
  }

  var body: some View {
    SettingsPage {
      SettingsPageHeader(title: "Randomazzo", summary: "Your collection of looks for the bar.")
      savedPresets
      SettingsSection(title: "Randomizer Hotkey") {
        HStack {
          Text("Roll random").frame(width: 130, alignment: .leading)
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
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
          }
        }
        Text("Format: modifier+modifier+key (e.g. ctrl+option+r). Set to \"false\" to disable.")
          .font(.caption).foregroundStyle(.secondary)
      }
      SettingsSection(title: "Options") {
        Toggle("Exclude current config when rolling", isOn: $excludeCurrent)
          .onChange(of: excludeCurrent) { _, newValue in
            guard !isSyncing else { return }
            UserDefaults.standard.randomazzoExcludeCurrent = newValue
          }
      }
    }
    .onAppear {
      syncFromUserDefaults()
      refreshAvailability()
    }
    .onChange(of: availabilityKeys) { _, _ in
      refreshAvailability()
      clearHiddenSelection()
    }
    .onChange(of: searchText) { _, _ in clearHiddenSelection() }
  }

  private var savedPresets: some View {
    SettingsSection(title: "Saved Presets") {
      collectionActions
      if store.entries.isEmpty {
        VStack(spacing: 8) {
          Text("🪴").font(.system(size: 36))
          Text("Your collection starts here").font(.headline)
          Text("Add your current bar, then try a new look whenever you like.")
            .font(.callout).foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 24)
      } else {
        searchAndSort
        Text(presetCount).font(.caption).foregroundStyle(.secondary)
        if visibleEntries.isEmpty {
          VStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.title2).foregroundStyle(.secondary)
            Text("No matching presets").font(.headline)
            Text("Try a different name or clear your search.")
              .font(.callout).foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, minHeight: 180)
        } else {
          presetList
        }
        Divider()
        selectionActions
        Text("Select a preset to apply it. Icons stay with their presets until you shuffle them.")
          .font(.caption).foregroundStyle(.secondary)
      }
    }
  }

  private var collectionActions: some View {
    HStack(spacing: 10) {
      Button(action: addCurrentConfig) {
        Label("Add Current Bar…", systemImage: "plus")
      }
      Button(action: roll) {
        Label("Roll Random", systemImage: "dice.fill")
      }
      .buttonStyle(.borderedProminent)
      .disabled(store.entries.isEmpty)
      Spacer()
      if !store.entries.isEmpty {
        Menu {
          Button("Shuffle All Icons", systemImage: "sparkles") { store.shuffleAllIcons() }
        } label: {
          Image(systemName: "ellipsis.circle")
        }
        .menuStyle(.borderlessButton).fixedSize()
        .help("Preset collection options")
        .accessibilityLabel("Preset collection options")
      }
    }
  }

  private var searchAndSort: some View {
    HStack(spacing: 12) {
      HStack(spacing: 7) {
        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
        TextField("Find a preset", text: $searchText)
          .textFieldStyle(.plain).accessibilityLabel("Search presets")
        if !searchText.isEmpty {
          Button {
            searchText = ""
          } label: {
            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
          }
          .buttonStyle(.plain).accessibilityLabel("Clear preset search")
        }
      }
      .padding(9)
      .background(.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
      Picker("Sort presets", selection: $sortOrder) {
        ForEach(PresetSort.allCases) { order in Text(order.rawValue).tag(order) }
      }
      .labelsHidden().frame(width: 140)
    }
  }

  private var presetList: some View {
    List(visibleEntries, selection: $selectedName) { entry in
      RandomazzoPresetRow(entry: entry, unavailable: unavailableNames.contains(entry.name))
        .tag(entry.name)
        .listRowSeparator(.hidden)
        .contextMenu {
          Button("Apply Preset", systemImage: "checkmark.circle") {
            applyPreset(named: entry.name)
          }
          .disabled(unavailableNames.contains(entry.name))
          Button("Rename…", systemImage: "pencil") { renamePreset(entry) }
          Button("Shuffle Icon", systemImage: "sparkles") { store.shuffleIcon(for: entry.name) }
          Divider()
          Button("Delete Preset", systemImage: "trash", role: .destructive) {
            deletePreset(named: entry.name)
          }
        }
    }
    .listStyle(.plain).scrollContentBackground(.hidden)
    .frame(height: 390)
    .background(.background.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .accessibilityLabel("Saved presets")
  }

  private var selectionActions: some View {
    HStack(spacing: 10) {
      Button("Apply Preset") {
        if let name = selectedName { applyPreset(named: name) }
      }
      .disabled(selectedName == nil || unavailableNames.contains(selectedName ?? ""))
      Button("Rename…") {
        if let entry = store.entries.first(where: { $0.name == selectedName }) {
          renamePreset(entry)
        }
      }
      .disabled(selectedName == nil)
      Button("Shuffle Icon", systemImage: "sparkles") {
        if let name = selectedName { store.shuffleIcon(for: name) }
      }
      .disabled(selectedName == nil)
      Spacer()
      Button("Delete", systemImage: "trash", role: .destructive) {
        if let name = selectedName { deletePreset(named: name) }
      }
      .disabled(selectedName == nil)
    }
  }

  private func refreshAvailability() {
    unavailableNames = Set(store.entries.filter { store.isCorrupted($0.name) }.map(\.name))
  }

  private func clearHiddenSelection() {
    if let name = selectedName, !visibleEntries.contains(where: { $0.name == name }) {
      selectedName = nil
    }
  }

  private func addCurrentConfig() {
    promptForName { name in
      guard let name else { return }
      if !name.isEmpty, store.exists(name), !confirmOverwrite(name) { return }
      store.save(name: name)
    }
  }

  private func applyPreset(named name: String) {
    if let result = store.applyConfig(named: name) {
      AppLogger.shared.info("Applied config: \(result)", category: .app)
    } else {
      AppLogger.shared.error("Failed to apply config: '\(name)'", category: .app)
    }
  }

  private func renamePreset(_ entry: RandomazzoEntry) {
    promptForName(initial: entry.name) { newName in
      guard let newName, !newName.isEmpty, newName != entry.name else { return }
      if store.exists(newName), !confirmOverwrite(newName) { return }
      store.rename(from: entry.name, to: newName)
      selectedName = newName
      clearHiddenSelection()
    }
  }

  private func deletePreset(named name: String) {
    store.delete(name: name)
    if selectedName == name { selectedName = nil }
  }

  private func confirmOverwrite(_ name: String) -> Bool {
    let alert = NSAlert()
    alert.messageText = "A config named '\(name)' already exists."
    alert.informativeText = "Do you want to overwrite it?"
    alert.addButton(withTitle: "Overwrite")
    alert.addButton(withTitle: "Cancel")
    return alert.runModal() == .alertFirstButtonReturn
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
    alert.messageText = initial == nil ? "Save Configuration" : "Rename Preset"
    alert.informativeText =
      initial == nil
      ? "Enter a name for this configuration (leave empty for auto-name):"
      : "Enter a new name for this preset:"
    alert.addButton(withTitle: initial == nil ? "Save" : "Rename")
    alert.addButton(withTitle: "Cancel")
    let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
    textField.stringValue = initial ?? ""
    alert.accessoryView = textField
    if alert.runModal() == .alertFirstButtonReturn {
      completion(textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
    } else {
      completion(nil)
    }
  }
}
