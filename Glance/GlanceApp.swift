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
        if CommandLine.arguments.contains("--benchmark-panel"), argumentValue(after: "--config") == nil {
            fputs("--benchmark-panel requires an explicit disposable --config path\n", stderr)
            exit(EXIT_FAILURE)
        }
        for ext in ["ttf", "otf"] {
            for fontURL in Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil) ?? [] {
                CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
            }
        }
        if let previewPath = ProcessInfo.processInfo.environment["GLANCE_PREVIEW_BAR_PATH"]
            ?? argumentValue(after: "--export-bar") {
            if CommandLine.arguments.contains("--export-shuffled-palette") { ConfigManager.shared.shuffleWidgetPalette() }
            let width = argumentValue(after: "--export-width").flatMap(Double.init) ?? 1600
            guard BarPreviewExporter.export(
                to: URL(fileURLWithPath: previewPath),
                width: width,
                verticalLength: argumentValue(after: "--export-height").flatMap(Double.init) ?? 900,
                topInset: argumentValue(after: "--export-top-inset").flatMap(Double.init) ?? 0,
                bottomInset: argumentValue(after: "--export-bottom-inset").flatMap(Double.init) ?? 0
            ) else {
                exit(EXIT_FAILURE)
            }
            return
        }

        if let path = argumentValue(after: "--export-music-info") {
            exit(MusicInfoExporter.export(to: URL(fileURLWithPath: path)) ? EXIT_SUCCESS : EXIT_FAILURE)
        }

        if let path = argumentValue(after: "--export-module-editor"), let module = argumentValue(after: "--module") {
            _ = NSApplication.shared
            NSApp.setActivationPolicy(.prohibited)
            exit(ModuleEditorExporter.export(module: module, to: URL(fileURLWithPath: path)) ? EXIT_SUCCESS : EXIT_FAILURE)
        }
        GlanceApp.main()
    }

    private static func argumentValue(after option: String) -> String? {
        guard let index = CommandLine.arguments.firstIndex(of: option),
              CommandLine.arguments.indices.contains(index + 1) else { return nil }
        return CommandLine.arguments[index + 1]
    }
}
