import AppKit
import SwiftUI

/// Captures the real module editor through AppKit drawing rather than desktop
/// capture. Callers use an isolated config so editing previews cannot affect
/// the active bar or preset library.
@MainActor enum ModuleEditorExporter {
    static func export(module: String, to url: URL) -> Bool {
        guard ConfigManager.shared.initError == nil else { return false }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 860, height: 1100), styleMask: [.borderless], backing: .buffered, defer: false)
        let editor: AnyView
        switch module {
        case "default.time": editor = AnyView(TimeSettingsTab())
        case "default.spaces": editor = AnyView(SpacesSettingsTab())
        default: editor = AnyView(WidgetsSettingsTab(moduleID: module))
        }
        let host = NSHostingView(rootView: editor)
        window.contentView = host
        host.frame = NSRect(x: 0, y: 0, width: 860, height: 1100)
        window.layoutIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))
        host.layoutSubtreeIfNeeded()
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return false }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { return false }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url)
            print("Module editor exported: " + url.path)
            return true
        } catch { fputs("Module editor export failed: \(error)\n", stderr); return false }
    }
}
