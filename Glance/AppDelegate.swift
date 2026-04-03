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
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    private var hotkeyManager: HotkeyManager?
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
        setupFullscreenDetection()
        WindowGapManager.shared.start()
        
        // Configure yabai external_bar based on bar position
        configureYabaiExternalBar()

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

    /// Configures and displays the background and menu bar panels.
    private func setupPanels() {
        guard let screenFrame = NSScreen.main?.frame else { return }
        let fg = ConfigManager.shared.config.experimental.foreground
        let barHeight = fg.resolveHeight()
        let topMargin = fg.topMargin
        let bottomMargin = fg.position == "bottom" ? topMargin : 0
        
        // Menu bar panel: positioned at top or bottom based on config
        let menuBarFrame: NSRect
        if fg.position == "bottom" {
            // Bottom position
            menuBarFrame = NSRect(
                x: screenFrame.origin.x,
                y: screenFrame.origin.y + bottomMargin,
                width: screenFrame.size.width,
                height: barHeight
            )
        } else {
            // Top position (default)
            menuBarFrame = NSRect(
                x: screenFrame.origin.x,
                y: screenFrame.origin.y + screenFrame.size.height - barHeight - topMargin,
                width: screenFrame.size.width,
                height: barHeight
            )
        }
        
        setupPanel(
            &backgroundPanel,
            frame: screenFrame,
            level: Int(CGWindowLevelForKey(.desktopWindow)),
            hostingRootView: AnyView(BackgroundView()))
        setupPanel(
            &menuBarPanel,
            frame: menuBarFrame,
            level: Int(CGWindowLevelForKey(.backstopMenu)),
            hostingRootView: AnyView(MenuBarView()))
    }

    /// Updates the menu bar panel frame to match current config (bar height + margins).
    private func updateMenuBarPanelFrame() {
        guard let screenFrame = NSScreen.main?.frame else { return }
        let fg = ConfigManager.shared.config.experimental.foreground
        let barHeight = fg.resolveHeight()
        let topMargin = fg.topMargin
        let bottomMargin = fg.position == "bottom" ? topMargin : 0
        
        let newFrame: NSRect
        if fg.position == "bottom" {
            newFrame = NSRect(
                x: screenFrame.origin.x,
                y: screenFrame.origin.y + bottomMargin,
                width: screenFrame.size.width,
                height: barHeight
            )
        } else {
            newFrame = NSRect(
                x: screenFrame.origin.x,
                y: screenFrame.origin.y + screenFrame.size.height - barHeight - topMargin,
                width: screenFrame.size.width,
                height: barHeight
            )
        }
        
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
                hostingRootView: AnyView(MenuBarView()))
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

        let manager = HotkeyManager()
        manager.onToggle = { [weak self] in
            self?.toggleBarVisibility()
        }
        manager.register(modifiers: parsed.modifiers, keyCode: parsed.keyCode)
        hotkeyManager = manager
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
