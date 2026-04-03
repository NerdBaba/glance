import AppKit
import SwiftUI

/// Manages font loading, caching, and native macOS font panel integration.
final class FontManager: NSObject {
    static let shared = FontManager()
    
    /// Cache of loaded NSFont instances
    private var fontCache: [String: NSFont] = [:]
    
    /// Cache of SwiftUI Font instances
    private var swiftUIFontCache: [String: Font] = [:]
    
    /// Completion handler for font panel selection
    private var fontSelectionHandler: ((String, CGFloat) -> Void)?
    
    override private init() {
        super.init()
        NSFontManager.shared.target = self
    }
    
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
    
    // MARK: - Native Font Panel
    
    /// Open the native macOS font panel.
    /// - Parameters:
    ///   - initialFontName: Initial font name (nil = system default)
    ///   - initialSize: Initial font size
    ///   - parentWindow: Window to present over
    ///   - completion: Called when user selects a font with (fontName, fontSize)
    func openFontPanel(
        initialFontName: String?,
        initialSize: CGFloat,
        parentWindow: NSWindow?,
        completion: @escaping (String, CGFloat) -> Void
    ) {
        fontSelectionHandler = completion
        
        DispatchQueue.main.async {
            // Get or create the font panel
            let fontPanel = NSFontManager.shared.fontPanel(true)
            
            // Create initial font
            let initialFont: NSFont
            if let fontName = initialFontName, !fontName.isEmpty,
               let font = NSFont(name: fontName, size: initialSize) {
                initialFont = font
            } else {
                initialFont = NSFont.systemFont(ofSize: initialSize)
            }
            
            // Set the font in the panel
            NSFontManager.shared.setSelectedFont(initialFont, isMultiple: false)
            
            // Show the panel
            fontPanel?.makeKeyAndOrderFront(parentWindow)
            fontPanel?.orderFrontRegardless()
        }
    }
    
    // MARK: - Font Panel Action Handler
    
    @objc func changeFont(_ sender: NSFontManager?) {
        guard let fontManager = sender,
              let handler = fontSelectionHandler,
              let oldFont = fontManager.selectedFont else {
            return
        }
        
        // Get the new font from the font manager
        let newFont = fontManager.convert(oldFont)
        
        handler(newFont.fontName, newFont.pointSize)
        fontSelectionHandler = nil
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
