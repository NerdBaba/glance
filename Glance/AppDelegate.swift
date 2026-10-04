import Combine
import ServiceManagement
import Sparkle
import SwiftUI

/// NSHostingView subclass that enables vibrancy for glass effects.
class GlanceHostingView<Content: View>: NSHostingView<Content> {
    override var allowsVibrancy: Bool { true }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var backgroundPanel: NSPanel?
    private var menuBarPanel: NSPanel?
    private var statusItem: NSStatusItem?
    private lazy var updaterController = SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    private var hotkeyManager = HotkeyManager()
    private var toggleHotkeyID: UInt32?
    private var randomazzoHotkeyID: UInt32?
    private var fullscreenDetector: FullscreenDetector?
    private var fullscreenCancellable: AnyCancellable?
    private var configCancellable: AnyCancellable?
    private var barVisible = true
    private var userHidBar = false  // True when user manually hid bar via hotkey

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let error = ConfigManager.shared.initError {
            showFatalConfigError(message: error)
            return
        }

        // Inspect settings with an isolated config without starting bar services.
        if CommandLine.arguments.contains("--preview-settings") {
            SettingsWindowController.shared.showSettings()
            return
        }

        // A diagnostic panel uses stable preview widgets and does not seed
        // presets, change window gaps, or start normal application services.
        if CommandLine.arguments.contains("--preview-panel") {
            guard let screenFrame = NSScreen.main?.frame else { return }
            let previewFrame = menuBarFrame(on: screenFrame)
            setupPanel(
                &menuBarPanel,
                frame: previewFrame,
                level: Int(CGWindowLevelForKey(.backstopMenu)),
                hostingRootView: AnyView(BarPanelContent()))
            menuBarPanel?.title = "Glance Bar Preview"
            configCancellable = ConfigManager.shared.$config
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.updateMenuBarPanelFrame() }
            AppLogger.shared.info("Preview panel launched: \(NSStringFromRect(previewFrame))", category: .app)
            return
        }

        // Seed bundled theme snapshots into Randomazzo on normal app launches.
        _ = RandomazzoStore.shared

        // Show "What's New" banner if the app version is outdated
        if !VersionChecker.isLatestVersion() {
            VersionChecker.updateVersionFile()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                NotificationCenter.default.post(
                    name: Notification.Name("ShowWhatsNewBanner"), object: nil)
            }
        }

        MenuBarPopup.setup()
        setupPanels()
        setupStatusItem()
        setupHotkey()
        setupRandomazzoHotkey()
        setupFullscreenDetection()
        WindowGapManager.shared.start()
        
        // Configure yabai external_bar based on bar position
        configureYabaiExternalBar()
        
        // Additional delayed yabai config update to handle cold launch timing
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.configureYabaiExternalBar()
        }

        // Update panel frames when config changes (e.g., bar height)
        configCancellable = ConfigManager.shared.$config
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateMenuBarPanelFrame()
                self?.configureYabaiExternalBar()
            }

        // Show onboarding on first launch
        OnboardingWindowController.shared.showIfNeeded()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil)
    }
    
    /// Configures yabai external_bar based on current bar position and dimensions.
    private func configureYabaiExternalBar() {
        let fg = ConfigManager.shared.config.experimental.foreground
        let position = fg.position
        let barHeight = fg.resolveHeight()
        let topMargin = fg.topMargin
        
        YabaiConfigManager.shared.updateExternalBarConfig(
            position: position,
            barHeight: barHeight,
            topMargin: topMargin
        )
    }

    @objc private func screenParametersDidChange(_ notification: Notification) {
        setupPanels()
    }

    // MARK: - Status Item (Tray Icon)

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            let image = NSImage(systemSymbolName: "eye", accessibilityDescription: "Glance")
            image?.size = NSSize(width: 18, height: 18)
            image?.isTemplate = true
            button.image = image
            button.toolTip = "Glance"
        }

        let menu = NSMenu()

        // Settings
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        // Check for Updates
        let updateItem = NSMenuItem(
            title: "Check for Updates...",
            action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)),
            keyEquivalent: "")
        updateItem.target = updaterController
        menu.addItem(updateItem)

        menu.addItem(NSMenuItem.separator())

        // Launch at Login
        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = isLaunchAtLoginEnabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit Glance", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.showSettings()
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let service = SMAppService.mainApp
        do {
            if isLaunchAtLoginEnabled {
                try service.unregister()
                sender.state = .off
            } else {
                try service.register()
                sender.state = .on
            }
        } catch {
            AppLogger.shared.error("Failed to toggle launch at login: \(error.localizedDescription)", category: .app)
        }
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private var isLaunchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    // MARK: - Panels

    private func menuBarFrame(on screenFrame: NSRect) -> NSRect {
        let config = ConfigManager.shared.config
        let fg = config.experimental.foreground
        let scale = fg.renderingScale(for: screenFrame.width)
        let height = max(fg.resolveHeight(), 1) * scale
        let insets = BarDrawingInsets(appearance: config.appearance, foreground: fg)
        let barY = fg.position == "bottom"
            ? screenFrame.minY + fg.topMargin * scale
            : screenFrame.maxY - height - fg.topMargin * scale
        return NSRect(
            x: screenFrame.minX,
            y: barY - insets.bottom * scale,
            width: screenFrame.width,
            height: height + (insets.top + insets.bottom) * scale)
    }

    /// Configures and displays the background and menu bar panels.
    private func setupPanels() {
        guard let screenFrame = NSScreen.main?.frame else { return }
        setupPanel(
            &backgroundPanel,
            frame: screenFrame,
            level: Int(CGWindowLevelForKey(.desktopWindow)),
            hostingRootView: AnyView(BackgroundView()))
        setupPanel(
            &menuBarPanel,
            frame: menuBarFrame(on: screenFrame),
            level: Int(CGWindowLevelForKey(.backstopMenu)),
            hostingRootView: AnyView(BarPanelContent()))
    }

    /// Updates the menu bar panel frame to match current config (bar height + margins).
    private func updateMenuBarPanelFrame() {
        guard let screenFrame = NSScreen.main?.frame else { return }
        let newFrame = menuBarFrame(on: screenFrame)
        
        if let panel = menuBarPanel {
            if panel.frame != newFrame {
                panel.setFrame(newFrame, display: true, animate: false)
            }
        } else {
            // Panel doesn't exist yet, create it
            setupPanel(
                &menuBarPanel,
                frame: newFrame,
                level: Int(CGWindowLevelForKey(.backstopMenu)),
                hostingRootView: AnyView(BarPanelContent()))
        }
    }

    /// Sets up an NSPanel with the provided parameters.
    private func setupPanel(
        _ panel: inout NSPanel?, frame: CGRect, level: Int,
        hostingRootView: AnyView
    ) {
        if let existingPanel = panel {
            existingPanel.setFrame(frame, display: true)
            return
        }

        let newPanel = NSPanel(
            contentRect: frame,
            styleMask: [.nonactivatingPanel],
            backing: .buffered,
            defer: false)
        newPanel.level = NSWindow.Level(rawValue: level)
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = false
        newPanel.collectionBehavior = [.canJoinAllSpaces]
        newPanel.titlebarAppearsTransparent = true

        let hostingView = GlanceHostingView(rootView: hostingRootView)
        newPanel.contentView = hostingView

        newPanel.orderFront(nil)
        panel = newPanel
    }

    // MARK: - Hotkey (Show/Hide Bar)

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

    private func toggleBarVisibility() {
        barVisible.toggle()
        userHidBar = !barVisible
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            menuBarPanel?.animator().alphaValue = barVisible ? 1 : 0
            backgroundPanel?.animator().alphaValue = barVisible ? 1 : 0
        }
    }

    // MARK: - Randomazzo Hotkey

    private func setupRandomazzoHotkey() {
        let hotkeyString = UserDefaults.standard.randomazzoHotkey
        guard let parsed = HotkeyManager.parse(hotkeyString) else { return }

        // Conflict check: if same as toggle hotkey, skip
        if let toggleConfig = ConfigManager.shared.config.rootToml.hotkey,
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

    private func rollRandomazzo() {
        _ = RandomazzoStore.shared.roll(excludeCurrent: nil)
    }

    // MARK: - Fullscreen Auto-Hide

    private func setupFullscreenDetection() {
        let autoHide = ConfigManager.shared.config.experimental.foreground.autoHide
        guard autoHide else { return }

        let detector = FullscreenDetector()
        fullscreenDetector = detector
        fullscreenCancellable = detector.$isFullscreen
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] shouldHide in
                self?.applyFullscreenVisibility(shouldHide: shouldHide)
            }
    }

    private func applyFullscreenVisibility(shouldHide: Bool) {
        guard !userHidBar else { return }

        if shouldHide && barVisible {
            barVisible = false
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.3
                menuBarPanel?.animator().alphaValue = 0
                backgroundPanel?.animator().alphaValue = 0
            }
        } else if !shouldHide && !barVisible {
            barVisible = true
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.3
                menuBarPanel?.animator().alphaValue = 1
                backgroundPanel?.animator().alphaValue = 1
            }
        }
    }

    private func showFatalConfigError(message: String) {
        let alert = NSAlert()
        alert.messageText = "Configuration Error"
        alert.informativeText = "\(message)\n\nUsing fallback config. Check ~/.glance-config.toml."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        
        alert.runModal()
    }
}
