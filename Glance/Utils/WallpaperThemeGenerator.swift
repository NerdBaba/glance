import AppKit
import Foundation

/// Generates a candidate Glance bar configuration anchored to an existing theme
/// template, recolored from the desktop wallpaper. The generated file keeps the
/// template's `pywal:N` symbols — the wallpaper palette is supplied at render
/// time, so no color values are hard-coded here.
///
/// This is the deterministic "template anchoring" core of the wallpaper→bar
/// flow. A later generative step may add option widget/layout tweaks on top.
enum WallpaperThemeGenerator {

    // MARK: - Public

    /// Run the CLI command. Exit status is returned for `exit()`.
    @MainActor
    static func runFromCommandLine() -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser.path

        // Source config: an explicit template file, else the live config.
        var source: String
        if let templatePath = argumentValue(after: "--template") {
            guard let text = try? String(contentsOfFile: templatePath, encoding: .utf8) else {
                fputs("Glance generate failed: template not found or unreadable at \(templatePath)\n", stderr)
                return false
            }
            source = text
        } else if let live = liveConfigPath() {
            guard let text = try? String(contentsOfFile: live, encoding: .utf8) else {
                fputs("Glance generate failed: could not read live config at \(live)\n", stderr)
                return false
            }
            source = text
        } else {
            source = ""
        }

        let generated = injectWallpaperPalette(into: source)

        // Output path: --apply writes the live config; --out wins next; else a
        // generated-file location under Application Support.
        let outPath: String
        if let out = argumentValue(after: "--out") {
            outPath = out
        } else if CommandLine.arguments.contains("--apply"), let live = liveConfigPath() {
            outPath = live
        } else {
            let support = home + "/Library/Application Support/glance/generated"
            try? FileManager.default.createDirectory(atPath: support, withIntermediateDirectories: true)
            outPath = support + "/wallpaper-config.toml"
        }

        do {
            try generated.write(toFile: outPath, atomically: true, encoding: .utf8)
        } catch {
            fputs("Glance generate failed: cannot write \(outPath): \(error.localizedDescription)\n", stderr)
            return false
        }

        // Report the extracted wallpaper palette.
        var paletteHex = [String]()
        if let url = WallpaperPalette.currentWallpaperURL(),
           let colors = WallpaperPalette.extract(from: url) {
            paletteHex = colors.colors.map { hex(NSColor($0)) }
        }
        print("Glance generate: wrote candidate config to \(outPath)")
        if paletteHex.isEmpty {
            print("Glance generate: no wallpaper palette available (headless preview?); colors will fall back.")
        } else {
            print("Glance generate: wallpaper palette (darkest→lightest):")
            print(paletteHex.enumerated().map { "  \($0.offset): \($0.element)" }.joined(separator: "\n"))
        }
        print("Glance generate: preview with: GLANCE_CONFIG_PATH=\(outPath) GLANCE_PREVIEW_BAR_PATH=preview.png")
        print("  \(CommandLine.arguments[0]) --export-bar")
        return true
    }

    // MARK: - TOML injection

    /// Ensure `[experimental] wallpaper-palette = true` is present in a config.
    static func injectWallpaperPalette(into source: String) -> String {
        let lines = source.components(separatedBy: "\n")
        var experimentalIndex: Int?

        for (i, raw) in lines.enumerated() {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line == "[experimental]" {
                experimentalIndex = i
                break
            }
        }

        // Already present?
        if lines.contains(where: { $0.contains("wallpaper-palette") }) {
            return source
        }

        let flagLine = "wallpaper-palette = true"

        guard let expIndex = experimentalIndex else {
            // No [experimental] table — append one.
            var out = source
            if !out.isEmpty && !out.hasSuffix("\n") { out += "\n" }
            out += "\n[experimental]\n\(flagLine)\n"
            return out
        }

        // Insert as the first key of the [experimental] table, before the next
        // section header or at end of file.
        var insertAt = lines.count
        for j in (expIndex + 1)..<lines.count {
            let line = lines[j].trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("[") && line.hasSuffix("]") {
                insertAt = j
                break
            }
        }
        var out = lines
        out.insert(flagLine, at: insertAt)
        return out.joined(separator: "\n")
    }

    // MARK: - Helpers

    private static func liveConfigPath() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path1 = home + "/.glance-config.toml"
        if FileManager.default.fileExists(atPath: path1) { return path1 }
        let path2 = home + "/.config/glance/config.toml"
        if FileManager.default.fileExists(atPath: path2) { return path2 }
        return path1
    }

    private static func argumentValue(after option: String) -> String? {
        guard let index = CommandLine.arguments.firstIndex(of: option),
              CommandLine.arguments.indices.contains(index + 1) else { return nil }
        return CommandLine.arguments[index + 1]
    }

    private static func hex(_ color: NSColor) -> String {
        let srgb = color.usingColorSpace(.sRGB) ?? color
        let r = Int((srgb.redComponent * 255).rounded())
        let g = Int((srgb.greenComponent * 255).rounded())
        let b = Int((srgb.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
