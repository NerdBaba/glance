import AppKit
import Combine
import Foundation

class SpacesViewModel: ObservableObject {
    @Published var spaces: [AnySpace] = []
    @Published var isUnavailable = false
    private var timer: Timer?
    private var provider: AnySpacesProvider?
    private var appLaunchObserver: NSObjectProtocol?
    private var appTerminateObserver: NSObjectProtocol?
    private var activateObserver: NSObjectProtocol?
    private var spaceChangeObserver: NSObjectProtocol?

    // Debounce: only fire loadSpaces after a quiet period to avoid redundant spawns.
    // 0.15s — just enough to merge the immediate event cascade (space switch fires
    // activeSpaceDidChange + didActivateApplication within ~50-100ms of each other).
    // Native mode is fully event-driven; yabai/AeroSpace use a slow poll fallback.
    private var loadWorkItem: DispatchWorkItem?
    private let debounceInterval: TimeInterval = 0.15

    init() {
        let runningApps = NSWorkspace.shared.runningApplications.compactMap {
            $0.localizedName?.lowercased()
        }
        if runningApps.contains("yabai") {
            provider = AnySpacesProvider(YabaiSpacesProvider())
        } else if runningApps.contains("aerospace") {
            provider = AnySpacesProvider(AerospaceSpacesProvider())
        } else {
            provider = AnySpacesProvider(NativeSpacesProvider())
        }
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    private func startMonitoring() {
        // For native macOS, use workspace notifications as primary trigger — no polling needed.
        // For yabai/AeroSpace, keep a slow poll as fallback since their event system
        // isn't directly observable from a third-party app.
        let isThirdParty = provider?.isYabai == true || provider?.isAerospace == true
        if isThirdParty {
            timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) {
                [weak self] _ in
                self?.debounceLoadSpaces()
            }
            timer?.tolerance = 0.5
        }
        // Native mode: no timer — fully event-driven via notifications below.

        let center = NSWorkspace.shared.notificationCenter

        // Listen for space changes — most reliable trigger for native macOS
        spaceChangeObserver = center.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.debounceLoadSpaces()
        }

        // App activation may change focused space
        activateObserver = center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.debounceLoadSpaces()
        }

        appLaunchObserver = center.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.debounceLoadSpaces()
        }

        appTerminateObserver = center.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.debounceLoadSpaces()
        }

        debounceLoadSpaces()
    }

    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        loadWorkItem?.cancel()
        loadWorkItem = nil

        let center = NSWorkspace.shared.notificationCenter
        if let obs = spaceChangeObserver { center.removeObserver(obs) }
        if let obs = activateObserver { center.removeObserver(obs) }
        if let obs = appLaunchObserver { center.removeObserver(obs) }
        if let obs = appTerminateObserver { center.removeObserver(obs) }
    }

    /// Debounced load — cancels any pending load and schedules a new one.
    /// This prevents the cascade of redundant spawns when multiple events fire close together.
    private func debounceLoadSpaces() {
        loadWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.loadSpaces()
        }
        loadWorkItem = workItem

        DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval, execute: workItem)
    }

    private func loadSpaces() {
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            guard let self = self,
                let provider = self.provider
            else {
                DispatchQueue.main.async {
                    self?.spaces = []
                }
                return
            }

            guard let newSpaces = provider.getSpacesWithWindows() else {
                DispatchQueue.main.async {
                    self.spaces = []
                    self.isUnavailable = true
                }
                return
            }

            let sortedSpaces = newSpaces.sorted { $0.id < $1.id }
            DispatchQueue.main.async {
                if self.isUnavailable { self.isUnavailable = false }
                // Only publish if spaces actually changed — avoids unnecessary SwiftUI re-renders
                if self.spaces != sortedSpaces {
                    self.spaces = sortedSpaces
                }
            }
        }
    }

    func switchToSpace(_ space: AnySpace, needWindowFocus: Bool = false) {
        DispatchQueue.global(qos: .userInitiated).async {
            self.provider?.focusSpace(
                spaceId: space.id, needWindowFocus: needWindowFocus)
        }
    }

    func switchToWindow(_ window: AnyWindow) {
        DispatchQueue.global(qos: .userInitiated).async {
            self.provider?.focusWindow(windowId: String(window.id))
        }
    }
}

extension AnySpacesProvider {
    var isYabai: Bool { self.wrapped is YabaiSpacesProvider }
    var isAerospace: Bool { self.wrapped is AerospaceSpacesProvider }
}

class IconCache {
    static let shared = IconCache()
    private let cache = NSCache<NSString, NSImage>()
    private init() {}
    func icon(for appName: String) -> NSImage? {
        if let cached = cache.object(forKey: appName as NSString) {
            return cached
        }
        let workspace = NSWorkspace.shared
        if let app = workspace.runningApplications.first(where: {
            $0.localizedName == appName
        }),
            let bundleURL = app.bundleURL
        {
            let icon = workspace.icon(forFile: bundleURL.path)
            cache.setObject(icon, forKey: appName as NSString)
            return icon
        }
        return nil
    }
}
