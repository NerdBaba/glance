import AppKit
import SwiftUI

/// Manages font loading and caching.
final class FontManager {
    static let shared = FontManager()
    
    /// Cache of loaded NSFont instances
    private var fontCache: [String: NSFont] = [:]
    
    /// Cache of SwiftUI Font instances
    private var swiftUIFontCache: [String: Font] = [:]
    
    private init() {}
    
    // MARK: - Font Loading
    
    /// Load a font by name and size, caching the result.
    func loadFont(name: String, size: CGFloat, weight: Font.Weight = .medium) -> NSFont? {
        let cacheKey = "\(name)_\(size)_\(weightToInt(weight))"
        
        if let cached = fontCache[cacheKey] {
            return cached
        }
        
        // Try to load the custom font
        if let font = NSFont(name: name, size: size) {
            fontCache[cacheKey] = font
            return font
        }
        
        // Fallback to system font with weight
        let systemFont = NSFont.systemFont(ofSize: size, weight: nsFontWeight(weight))
        fontCache[cacheKey] = systemFont
        return systemFont
    }
    
    /// Get a SwiftUI Font from config, using cache.
    func getSwiftUIFont(from config: FontConfig) -> Font {
        let cacheKey = "\(config.fontName ?? "system")_\(config.fontSize)_\(weightToInt(config.weight))"
        
        if let cached = swiftUIFontCache[cacheKey] {
            return cached
        }
        
        let font = config.toFont()
        swiftUIFontCache[cacheKey] = font
        return font
    }
    
    /// Get a SwiftUI Font with weight applied.
    func getSwiftUIFont(from config: FontConfig, withWeight weight: Font.Weight) -> Font {
        let cacheKey = "\(config.fontName ?? "system")_\(config.fontSize)_\(weightToInt(weight))"
        
        if let cached = swiftUIFontCache[cacheKey] {
            return cached
        }
        
        let font = config.withWeight(weight)
        swiftUIFontCache[cacheKey] = font
        return font
    }
    
    // MARK: - Helpers
    
    private func nsFontWeight(_ weight: Font.Weight) -> NSFont.Weight {
        switch weight {
        case .thin: return .thin
        case .ultraLight: return .ultraLight
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        default: return .regular
        }
    }
    
    private func weightToInt(_ weight: Font.Weight) -> Int {
        switch weight {
        case .thin: return 0
        case .ultraLight: return 1
        case .light: return 2
        case .regular: return 3
        case .medium: return 4
        case .semibold: return 5
        case .bold: return 6
        case .heavy: return 7
        case .black: return 8
        default: return 3
        }
    }
    
    /// Get list of available system fonts.
    func availableFontFamilies() -> [String] {
        NSFontManager.shared.availableFontFamilies.sorted()
    }
    
    /// Clear all font caches.
    func clearCache() {
        fontCache.removeAll()
        swiftUIFontCache.removeAll()
    }
}
