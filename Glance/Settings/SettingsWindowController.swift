import SwiftUI

/// Manages the Settings window lifecycle.
/// Since Glance is an LSUIElement app (no Dock icon), we manage
/// the Settings window manually via NSWindow.
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private var window: NSWindow?
    private var randomazzoToolbarItem: NSToolbarItem?

    private override init() {}

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

    func windowWillClose(_ notification: Notification) {
        window = nil
    }

    private func setupToolbar(window: NSWindow) {
        let toolbar = NSToolbar(identifier: "GlanceSettingsToolbar")
        toolbar.displayMode = .iconOnly
        toolbar.showsBaselineSeparator = true
        toolbar.delegate = self
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false

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
        // Post a notification that the SettingsView can observe
        NotificationCenter.default.post(
            name: Notification.Name("SwitchToRandomazzoTab"),
            object: nil
        )
    }
}

// MARK: - NSToolbarDelegate

extension SettingsWindowController: NSToolbarDelegate {
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard itemIdentifier == NSToolbarItem.Identifier("RandomazzoToolbarItem") else { return nil }

        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        let button = NSButton()
        button.image = NSImage(systemSymbolName: "dice.fill", accessibilityDescription: "Randomazzo")
        button.bezelStyle = .toolbar
        button.isBordered = false
        button.target = self
        button.action = #selector(showRandomazzoMenu(_:))

        item.view = button
        randomazzoToolbarItem = item
        return item
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [NSToolbarItem.Identifier("RandomazzoToolbarItem")]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [NSToolbarItem.Identifier("RandomazzoToolbarItem")]
    }

    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        []
    }
}
