import AppKit
import Foundation
import SwiftUI
import TOMLDecoder

/// A single generated bar variation with its headless preview.
struct BarVariationCandidate: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let patch: BarTweakPatch
    let previewURL: URL
    let image: NSImage?
}

/// Generates several *deterministic* bar variations locally (no extra API
/// calls): for each composition archetype it composes a widget layout, renders a
/// headless preview from a snapshot, and offers the result as a selectable
/// candidate. Applying one writes the same decisions the applier understands.
enum WallpaperVariation {

    private static let archetypes: [(BarComposition, String, Bool)] = [
        (.classicStatus, "floating", true),
        (.flanked, "full", false),
        (.asymmetricDock, "floating", true),
        (.layeredPills, "pills", true),
    ]

    @MainActor
    static func generateCandidates(manager: ConfigManager) -> [BarVariationCandidate] {
        guard let base = baseConfigText(manager) else { return [] }
        let palette = WallpaperThemeGenerator.paletteHexes(from: manager)
        let accent = bestAccentIndex(palette)
        let available = WallpaperTweakApplier.availableWidgetIDs(manager: manager)
        let dir = previewDirectory()

        return archetypes.compactMap { composition, formation, includeSystem in
            let list = WallpaperComposer.compose(composition, anchor: nil, available: available, includeSystem: includeSystem)

            var text = base
            text = inject(text, table: "experimental.foreground", key: "formation", value: formation)
            text = inject(text, table: "widgets.pywal", key: "accent-index", value: String(accent))
            text = inject(text, table: "widgets", key: "displayed", value: WallpaperTweakApplier.tomlArray(list))

            guard let root = try? TOMLDecoder().decode(RootToml.self, from: text) else { return nil }

            let url = dir.appendingPathComponent("variation-\(composition.rawValue).png")
            guard BarPreviewExporter.export(snapshot: root, pywalColors: manager.config.pywalColors,
                                            to: url, width: 1600) else { return nil }
            let image = NSImage(contentsOf: url)

            let decisions = [
                BarTweakDecision(key: "formation", value: formation, confidence: 1),
                BarTweakDecision(key: "accent-index", value: String(accent), confidence: 1),
                BarTweakDecision(key: "composition", value: composition.rawValue, confidence: 1),
            ]
            let patch = BarTweakPatch(decisions: decisions)
            return BarVariationCandidate(title: composition.label, subtitle: "\(formation) · accent \(accent)",
                                         patch: patch, previewURL: url, image: image)
        }
    }

    // MARK: - Config text

    private static func baseConfigText(_ manager: ConfigManager) -> String? {
        if let path = manager.configFilePath, let text = try? String(contentsOfFile: path, encoding: .utf8), !text.isEmpty {
            return text
        }
        return nil
    }

    /// Insert/update `key = value` inside `[table]`, creating the table if
    /// missing. If the key already exists in that table it is replaced; if not,
    /// the key is appended at the end of the table (before the next header).
    private static func inject(_ source: String, table: String, key: String, value: String) -> String {
        let header = "[\(table)]"
        let pattern = "^\(NSRegularExpression.escapedPattern(for: key))\\s*="
        let lines = source.components(separatedBy: "\n")

        // Locate the table span: start = header index, end = next [section] or EOF.
        guard let start = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == header }) else {
            var out = source
            if !out.isEmpty && !out.hasSuffix("\n") { out += "\n" }
            out += "\n\(header)\n\(key) = \(value)\n"
            return out
        }
        var end = lines.count
        for i in (start + 1)..<lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                end = i
                break
            }
        }

        // Replace an existing key within the table span.
        for i in (start + 1)..<end {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            if !trimmed.hasPrefix("#"), trimmed.range(of: pattern, options: .regularExpression) != nil {
                var out = lines
                out[i] = "\(key) = \(value)"
                return out.joined(separator: "\n")
            }
        }

        // Key missing: insert at the end of the table (before the next header).
        var out = lines
        out.insert("\(key) = \(value)", at: end)
        return out.joined(separator: "\n")
    }

    // MARK: - Palette / accent

    private static func bestAccentIndex(_ hexes: [String]) -> Int {
        guard hexes.count >= 16 else { return 4 }
        func lum(_ hex: String) -> Double {
            var value = hex
            if value.hasPrefix("#") { value.removeFirst() }
            guard value.count >= 6,
                  let rgb = UInt64(value.prefix(6), radix: 16) else { return 0.5 }
            let r = Double((rgb >> 16) & 0xFF) / 255
            let g = Double((rgb >> 8) & 0xFF) / 255
            let b = Double(rgb & 0xFF) / 255
            func lin(_ v: Double) -> Double { v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
            return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
        }
        let bg = lum(hexes[0])
        let fg = lum(hexes[15])
        var best = 4
        var bestScore = -1.0
        for i in stride(from: 2, through: 13, by: 2) {
            let l = lum(hexes[i])
            let score = min(abs(l - bg), abs(l - fg))
            if score > bestScore { bestScore = score; best = i }
        }
        return best
    }

    private static func previewDirectory() -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let dir = URL(fileURLWithPath: home + "/Library/Application Support/glance/generated/previews")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
