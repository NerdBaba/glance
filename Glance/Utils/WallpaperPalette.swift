import AppKit
import CoreGraphics
import ImageIO
import SwiftUI

/// Derives an ordered color palette from the desktop wallpaper so bars recolor
/// to match the background without requiring an external pywal run on the
/// wallpaper. The palette is ordered darkest → lightest, mirroring the layout
/// of pywal's `~/.cache/wal/colors` so existing `pywal:N` references keep their
/// intent (index 0 ≈ background, index 15 ≈ foreground).
enum WallpaperPalette {

    /// The current screen's wallpaper image URL, if any.
    static func currentWallpaperURL() -> URL? {
        guard let screen = NSScreen.screens.first else { return nil }
        return NSWorkspace.shared.desktopImageURL(for: screen)
    }

    /// Extract up to `target` colors from an image file. Returns nil when the
    /// image cannot be read or yields no usable pixels.
    static func extract(from url: URL, target: Int = 16) -> PywalColors? {
        guard target > 0, let pixels = sampledPixels(url: url), pixels.count > 1 else { return nil }
        let palette = dominantPalette(pixels, target: target)
        guard !palette.isEmpty else { return nil }
        return PywalColors(colors: palette.map(Color.init(nsColor:)))
    }

    // MARK: - Sampling

    /// Downsample the wallpaper to a small thumbnail and read its RGBA pixels.
    private static func sampledPixels(url: URL) -> [NSColor]? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 96,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { return nil }

        let width = thumbnail.width
        let height = thumbnail.height
        var buffer = [UInt8](repeating: 0, count: width * height * 4)
        let context = CGContext(
            data: &buffer, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        context?.draw(thumbnail, in: CGRect(x: 0, y: 0, width: width, height: height))

        var pixels = [NSColor]()
        pixels.reserveCapacity(width * height)
        var offset = 0
        for _ in 0..<(width * height) {
            let r = buffer[offset], g = buffer[offset + 1], b = buffer[offset + 2]
            offset += 4
            // Skip near-black pixels often left by opaque thumbnail corners.
            if r < 10 && g < 10 && b < 10 { continue }
            pixels.append(NSColor(srgbRed: CGFloat(r) / 255, green: CGFloat(g) / 255,
                                  blue: CGFloat(b) / 255, alpha: 1))
        }
        return pixels.isEmpty ? nil : pixels
    }

    // MARK: - Quantization & selection

    /// Bucket pixels into a coarse (4-bit/channel) histogram, then greedily pick
    /// well-separated representatives and sort them darkest-first.
    private static func dominantPalette(_ pixels: [NSColor], target: Int) -> [NSColor] {
        // Accumulate per-bucket sums so representatives are true averages.
        var sumR = [UInt16: Double]()
        var sumG = [UInt16: Double]()
        var sumB = [UInt16: Double]()
        var counts = [UInt16: Int]()

        for pixel in pixels {
            let key = quantKey(pixel)
            sumR[key, default: 0] += Double(pixel.redComponent)
            sumG[key, default: 0] += Double(pixel.greenComponent)
            sumB[key, default: 0] += Double(pixel.blueComponent)
            counts[key, default: 0] += 1
        }

        let candidates: [NSColor] = counts.keys.compactMap { key in
            guard let n = counts[key], n > 0 else { return nil }
            return NSColor(srgbRed: sumR[key]! / Double(n), green: sumG[key]! / Double(n),
                           blue: sumB[key]! / Double(n), alpha: 1)
        }.sorted { (counts[$0.keyQuant] ?? 0) > (counts[$1.keyQuant] ?? 0) }

        // Greedy selection: choose the most prominent colors that remain distinct
        // in luminance, so the palette has usable dark/light range.
        var chosen = [NSColor]()
        for candidate in candidates where chosen.count < target {
            if chosen.allSatisfy({ luminanceDistance($0, candidate) > 0.10 }) {
                chosen.append(candidate)
            }
        }
        // Top up remaining slots with the most prominent colors not yet selected.
        for candidate in candidates where chosen.count < target {
            if !chosen.contains(candidate) { chosen.append(candidate) }
        }
        return chosen.prefix(target).sorted { luminance($0) < luminance($1) }
    }

    private static func quantKey(_ color: NSColor) -> UInt16 {
        let r = UInt16(Int(color.redComponent * 255) >> 4)
        let g = UInt16(Int(color.greenComponent * 255) >> 4)
        let b = UInt16(Int(color.blueComponent * 255) >> 4)
        return (r << 8) | (g << 4) | b
    }

    // MARK: - Luminance

    /// Relative luminance (WCAG) from sRGB components.
    static func luminance(_ color: NSColor) -> Double {
        func lin(_ v: Double) -> Double {
            v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * lin(Double(color.redComponent))
            + 0.7152 * lin(Double(color.greenComponent))
            + 0.0722 * lin(Double(color.blueComponent))
    }

    private static func luminanceDistance(_ a: NSColor, _ b: NSColor) -> Double {
        abs(luminance(a) - luminance(b))
    }
}

private extension NSColor {
    /// The quantization key used during histogram building.
    var keyQuant: UInt16 {
        let r = UInt16(Int(redComponent * 255) >> 4)
        let g = UInt16(Int(greenComponent * 255) >> 4)
        let b = UInt16(Int(blueComponent * 255) >> 4)
        return (r << 8) | (g << 4) | b
    }
}
