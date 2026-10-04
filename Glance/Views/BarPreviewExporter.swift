import Foundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// Renders the configured bar into a PNG without registering a GUI app or
/// creating a visible panel. This makes theme comparisons repeatable and
/// avoids requiring screen-capture permission.
@MainActor
enum BarPreviewExporter {
    static func export(to url: URL, width: Double, topInset: Double = 0, bottomInset: Double = 0) -> Bool {
        guard width.isFinite, width > 0 else {
            fputs("Glance bar preview failed: width must be a positive number.\n", stderr)
            return false
        }

        guard topInset.isFinite, bottomInset.isFinite,
              (0...4096).contains(topInset), (0...4096).contains(bottomInset) else {
            fputs("Glance bar preview failed: insets must be between 0 and 4096 pixels.\n", stderr)
            return false
        }

        let configManager = ConfigManager.shared
        if let error = configManager.initError {
            fputs("Glance bar preview failed: \(error)\n", stderr)
            return false
        }

        let foreground = configManager.config.experimental.foreground
        let height = max(foreground.resolveHeight(), 1) * foreground.renderingScale(for: width)
        let renderer = ImageRenderer(content: ScaledBarContent(width: width)
            .padding(.top, topInset)
            .padding(.bottom, bottomInset))
        renderer.proposedSize = ProposedViewSize(width: width, height: height + topInset + bottomInset)
        renderer.scale = 1
        renderer.isOpaque = false

        guard let image = renderer.cgImage else {
            fputs("Glance bar preview failed: SwiftUI could not render the bar.\n", stderr)
            return false
        }

        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        } catch {
            fputs("Glance bar preview failed: \(error.localizedDescription)\n", stderr)
            return false
        }

        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            fputs("Glance bar preview failed: could not create a PNG destination.\n", stderr)
            return false
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            fputs("Glance bar preview failed: PNG encoding did not complete.\n", stderr)
            return false
        }

        fputs("Glance bar preview exported: \(url.path) (\(image.width)×\(image.height))\n", stdout)
        return true
    }
}
