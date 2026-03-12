import AppKit
import Foundation

final class FullscreenDetector: ObservableObject {
    @Published var isFullscreen = false

    private var observers: [NSObjectProtocol] = []

    init() {
        let center = NSWorkspace.shared.notificationCenter

        observers.append(center.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in self?.check() })

        observers.append(center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            // Small delay to let the window settle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self?.check()
            }
        })

        check()
    }

    deinit {
        for obs in observers {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
        }
    }

    private func check() {
        guard let screen = NSScreen.main else { return }
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return }

        // Skip our own app
        if frontApp.processIdentifier == ProcessInfo.processInfo.processIdentifier {
            return
        }

        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
        ) as? [[String: Any]] else {
            isFullscreen = false
            return
        }

        let screenFrame = screen.frame
        let pid = frontApp.processIdentifier

        for info in windowList {
            guard let wPID = info[kCGWindowOwnerPID as String] as? Int32,
                  wPID == pid,
                  let layer = info[kCGWindowLayer as String] as? Int,
                  layer == 0,
                  let bounds = info[kCGWindowBounds as String] as? [String: CGFloat]
            else { continue }

            let wWidth = bounds["Width"] ?? 0
            let wHeight = bounds["Height"] ?? 0

            if wWidth >= screenFrame.width && wHeight >= screenFrame.height {
                if !isFullscreen { isFullscreen = true }
                return
            }
        }

        if isFullscreen { isFullscreen = false }
    }
}
