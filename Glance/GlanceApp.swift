import SwiftUI
import CoreText

struct GlanceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    SettingsWindowController.shared.showSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}

/// Keep image export out of AppKit's application-registration path. A GUI app
/// launched as a command-line process can abort before AppDelegate is called;
/// this entry point lets preview renders run without creating NSApplication.
@main
enum GlanceEntryPoint {
    @MainActor
    static func main() {
        for (name, ext) in [("FontAwesome5Free-Solid", "otf"), ("Cherry13-Regular", "ttf"), ("SourceCodePro-Semibold", "otf")] {
            if let fontURL = Bundle.main.url(forResource: name, withExtension: ext) {
                CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
            }
        }
        if let previewPath = ProcessInfo.processInfo.environment["GLANCE_PREVIEW_BAR_PATH"]
            ?? argumentValue(after: "--export-bar") {
            let width = argumentValue(after: "--export-width").flatMap(Double.init) ?? 1600
            guard BarPreviewExporter.export(
                to: URL(fileURLWithPath: previewPath),
                width: width,
                topInset: argumentValue(after: "--export-top-inset").flatMap(Double.init) ?? 0,
                bottomInset: argumentValue(after: "--export-bottom-inset").flatMap(Double.init) ?? 0
            ) else {
                exit(EXIT_FAILURE)
            }
            return
        }

        GlanceApp.main()
    }

    private static func argumentValue(after option: String) -> String? {
        guard let index = CommandLine.arguments.firstIndex(of: option),
              CommandLine.arguments.indices.contains(index + 1) else { return nil }
        return CommandLine.arguments[index + 1]
    }
}
