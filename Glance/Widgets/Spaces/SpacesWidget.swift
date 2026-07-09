import SwiftUI

// MARK: - Display Mode & Highlight Style

enum SpacesDisplayMode: String {
    case icons         = "icons"        // Space number + app icons + focused window title (default)
    case numbers       = "numbers"      // Just space numbers in styled containers
    case dots          = "dots"         // Small circles: filled/hollow/focused
    case iconsOnly     = "icons-only"   // App icons only, no numbers
    case focusedOnly   = "focused-only" // Only show the focused space
    case customIcons   = "custom-icons" // Custom SF Symbol icon per space
    case words         = "words"        // Custom user-defined words per space
}

enum SpacesHighlight: String {
    case opacity   // Focused 100%, inactive 60% (default)
    case pill      // Accent capsule background behind focused
    case underline // Colored bar beneath focused
    case glow      // Soft accent glow around focused
    case inverted  // Solid background with inverted text color
}

enum NumeralSystem: String {
    case arabic     = "arabic"       // Western digits: 1, 2, 3
    case arabicIndic = "arabic-indic" // Eastern Arabic-Indic: ١, ٢, ٣
    case japanese   = "japanese"     // Japanese Kanji: 一, 二, 三
}

// MARK: - Numeral Conversion Utility

extension String {
    /// Convert a numeric string to the specified numeral system
    func convertToNumeralSystem(_ system: NumeralSystem) -> String {
        guard let number = Int(self) else { return self }

        switch system {
        case .arabic:
            return self // Western digits (default)
        case .arabicIndic:
            return number.toArabicIndic()
        case .japanese:
            return number.toJapaneseKanji()
        }
    }
}

// MARK: - NSImage Tinting Extension

extension NSImage {
    /// Create a template version of this image tinted with the given color
    func tinted(with color: Color) -> NSImage {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return self
        }
        
        let size = self.size
        let rect = CGRect(origin: .zero, size: size)
        
        // Convert SwiftUI Color to NSColor
        let nsColor = NSColor(color)
        
        let tinted = NSImage(size: size, flipped: false) { _ in
            // Draw the original image as a mask
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            
            // Set the tint color
            nsColor.set()
            
            // Draw using the original image as a template
            context.clip(to: rect, mask: cgImage)
            context.fill(rect)
            
            return true
        }
        
        tinted.isTemplate = false
        return tinted
    }
}

private extension Int {
    /// Convert integer to Eastern Arabic-Indic numerals
    func toArabicIndic() -> String {
        let arabicIndicDigits = ["٠", "١", "٢", "٣", "٤", "٥", "٦", "٧", "٨", "٩"]
        return String(abs(self)).map { char -> String in
            if let digit = Int(String(char)), digit >= 0 && digit <= 9 {
                return arabicIndicDigits[digit]
            }
            return String(char)
        }.joined()
    }

    /// Convert integer to Japanese Kanji numerals (simple form, 1-10+)
    func toJapaneseKanji() -> String {
        let kanjiDigits = ["〇", "一", "二", "三", "四", "五", "六", "七", "八", "九"]

        // For numbers 1-9, use single kanji
        if self >= 1 && self <= 9 {
            return kanjiDigits[self]
        }

        // For 10 and above, use compound form
        if self == 10 { return "十" }
        if self < 20 { return "十" + kanjiDigits[self % 10] }
        if self < 100 {
            let tens = self / 10
            let ones = self % 10
            let tensStr = tens == 1 ? "十" : kanjiDigits[tens] + "十"
            let onesStr = ones == 0 ? "" : kanjiDigits[ones]
            return tensStr + onesStr
        }

        // Fallback to regular digits for larger numbers
        return String(self)
    }
}

// MARK: - Inline Table Parser

func parseInlineTable(_ str: String) -> [String: String] {
    var result: [String: String] = [:]
    let trimmed = str.trimmingCharacters(in: .whitespaces)
        .replacingOccurrences(of: "{", with: "")
        .replacingOccurrences(of: "}", with: "")
    let pairs = trimmed.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    for pair in pairs {
        let parts = pair.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2 else { continue }
        let key = parts[0].replacingOccurrences(of: "\"", with: "")
        let value = parts[1].replacingOccurrences(of: "\"", with: "")
        result[key] = value
    }
    return result
}

// MARK: - Spaces Widget

struct SpacesWidget: View {
    @StateObject var viewModel = SpacesViewModel()

    @ObservedObject var configManager = ConfigManager.shared
    var foregroundHeight: CGFloat { configManager.config.experimental.foreground.resolveHeight() }

    var body: some View {
        Group {
            if viewModel.isUnavailable {
                Text("Spaces unavailable")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: foregroundHeight < 30 ? 0 : 8) {
                    ForEach(viewModel.spaces) { space in
                        SpaceView(space: space)
                    }
                }
            }
        }
        .experimentalConfiguration(horizontalPadding: 5)
        .animation(.smooth(duration: 0.3), value: viewModel.spaces)
        .environmentObject(viewModel)
        .widgetFontStyle()
    }
}

// MARK: - Space View (routes to display mode)

private struct SpaceView: View {
    @EnvironmentObject var configProvider: ConfigProvider
    @EnvironmentObject var viewModel: SpacesViewModel
    @Environment(\.appearance) private var appearance

    var config: ConfigData { configProvider.config }

    @ObservedObject var configManager = ConfigManager.shared
    var foregroundHeight: CGFloat { configManager.config.experimental.foreground.resolveHeight() }

    var showKey: Bool { config["space.show-key"]?.boolValue ?? true }

    var displayMode: SpacesDisplayMode {
        guard let raw = config["space.display-mode"]?.stringValue else { return .icons }
        return SpacesDisplayMode(rawValue: raw) ?? .icons
    }

    var highlight: SpacesHighlight {
        guard let raw = config["space.highlight"]?.stringValue else { return .opacity }
        return SpacesHighlight(rawValue: raw) ?? .opacity
    }

    var numeralSystem: NumeralSystem {
        guard let raw = config["space.numeral-system"]?.stringValue else { return .arabic }
        return NumeralSystem(rawValue: raw) ?? .arabic
    }

    var spaceWords: [String: String] {
        if let dict = config["space.words"]?.dictionaryValue {
            return dict.compactMapValues { $0.stringValue }
        }
        // Fallback: parse inline table string like "{ 2 = \"sss\", 1 = \"ss\" }"
        if let rawStr = config["space.words"]?.stringValue {
            return parseInlineTable(rawStr)
        }
        return [:]
    }

    let space: AnySpace

    @State var isHovered = false

    var body: some View {
        let isFocused = space.windows.contains { $0.isFocused } || space.isFocused
        let isOccupied = !space.windows.isEmpty

        // In focused-only mode, hide non-focused spaces
        if displayMode == .focusedOnly && !isFocused {
            EmptyView()
        } else {
            spaceContent(isFocused: isFocused, isOccupied: isOccupied)
                .highlightStyle(
                    highlight,
                    isFocused: isFocused,
                    isHovered: isHovered,
                    accentColor: appearance.accentColor
                )
                .contentShape(Rectangle())
                .transition(.blurReplace)
                .onTapGesture {
                    viewModel.switchToSpace(space, needWindowFocus: true)
                }
                .animation(.smooth, value: isHovered)
                .animation(.smooth, value: isFocused)
                .onHover { value in
                    isHovered = value
                }
        }
    }

    @ViewBuilder
    private func spaceContent(isFocused: Bool, isOccupied: Bool) -> some View {
        switch displayMode {
        case .icons, .focusedOnly:
            iconsContent(isFocused: isFocused)
        case .numbers:
            numbersContent(isFocused: isFocused)
        case .dots:
            dotsContent(isFocused: isFocused, isOccupied: isOccupied)
        case .iconsOnly:
            iconsOnlyContent(isFocused: isFocused)
        case .customIcons:
            customIconsContent(isFocused: isFocused)
        case .words:
            wordsContent(isFocused: isFocused)
        }
    }

    // MARK: - Icons Mode (default — number + app icons + title)

    @ViewBuilder
    private func iconsContent(isFocused: Bool) -> some View {
        HStack(spacing: 4) {
            if showKey {
                Text(space.id.convertToNumeralSystem(numeralSystem))
                    .font(.system(size: 12, weight: isFocused ? .bold : .regular))
                    .monospacedDigit()
                    .foregroundStyle(isFocused ? appearance.foregroundColor : appearance.foregroundColor.opacity(0.5))
                    .frame(width: 16, alignment: .center)
                    .fixedSize(horizontal: true, vertical: false)
            }
            HStack(spacing: 2) {
                ForEach(space.windows) { window in
                    WindowView(window: window, space: space)
                }
            }
        }
        .padding(.horizontal, 6)
        .frame(height: 30)
    }

    // MARK: - Numbers Mode (just space numbers)

    @ViewBuilder
    private func numbersContent(isFocused: Bool) -> some View {
        Text(space.id.convertToNumeralSystem(numeralSystem))
            .font(.system(size: 12, weight: isFocused ? .bold : .medium, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(isFocused ? appearance.foregroundColor : appearance.foregroundColor.opacity(0.5))
            .frame(width: 24, alignment: .center)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 4)
            .frame(height: 30)
    }

    // MARK: - Dots Mode (circles: focused/occupied/empty)

    @ViewBuilder
    private func dotsContent(isFocused: Bool, isOccupied: Bool) -> some View {
        let dotSize: CGFloat = isFocused ? 8 : 6

        Circle()
            .fill(isFocused ? appearance.accentColor : (isOccupied ? Color.white.opacity(0.7) : Color.white.opacity(0.25)))
            .frame(width: dotSize, height: dotSize)
            .animation(.smooth(duration: 0.2), value: isFocused)
            .padding(.horizontal, 3)
            .frame(height: 30)
    }

    // MARK: - Icons Only Mode (app icons, no numbers)

    @ViewBuilder
    private func iconsOnlyContent(isFocused: Bool) -> some View {
        HStack(spacing: 2) {
            if space.windows.isEmpty {
                // Show a small placeholder dot for empty spaces
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 6, height: 6)
            } else {
                ForEach(space.windows) { window in
                    WindowView(window: window, space: space)
                }
            }
        }
        .padding(.horizontal, 4)
        .frame(height: 30)
    }

    // MARK: - Custom Icons Mode (SF Symbol icon)

    @ViewBuilder
    private func customIconsContent(isFocused: Bool) -> some View {
        let iconSymbol = config["space.global-icon"]?.stringValue ?? "desktopcomputer"

        HStack(spacing: 4) {
            if showKey {
                Text(space.id.convertToNumeralSystem(numeralSystem))
                    .font(.system(size: 12, weight: isFocused ? .bold : .regular))
                    .monospacedDigit()
                    .foregroundStyle(isFocused ? appearance.foregroundColor : appearance.foregroundColor.opacity(0.5))
                    .frame(width: 16, alignment: .center)
                    .fixedSize(horizontal: true, vertical: false)
            }
            Image(systemName: iconSymbol)
                .font(.system(size: 14))
                .foregroundStyle(isFocused ? appearance.foregroundColor : appearance.foregroundColor.opacity(0.5))
        }
        .padding(.horizontal, 6)
        .frame(height: 30)
    }

    // MARK: - Words Mode (custom user-defined words)

    @ViewBuilder
    private func wordsContent(isFocused: Bool) -> some View {
        let word = spaceWords[space.id] ?? space.id

        Text(word)
            .font(.system(size: 12, weight: isFocused ? .bold : .medium))
            .foregroundStyle(isFocused ? appearance.foregroundColor : appearance.foregroundColor.opacity(0.5))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 6)
            .frame(height: 30)
    }
}

// MARK: - Color Inversion Utility

extension Color {
    /// Returns the inverse (negative) of this color by inverting RGB components
    func inverted() -> Color {
        let nsColor = NSColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        nsColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return Color(red: 1.0 - r, green: 1.0 - g, blue: 1.0 - b).opacity(a)
    }
}

// MARK: - Highlight Style Modifier

private struct HighlightModifier: ViewModifier {
    let style: SpacesHighlight
    let isFocused: Bool
    let isHovered: Bool
    let accentColor: Color

    func body(content: Content) -> some View {
        switch style {
        case .opacity:
            content
                .opacity(isFocused ? 1.0 : (isHovered ? 0.9 : 0.6))

        case .pill:
            content
                .background(
                    Capsule()
                        .fill(accentColor.opacity(isFocused ? 0.3 : 0))
                        .overlay(
                            Capsule()
                                .strokeBorder(accentColor.opacity(isFocused ? 0.4 : 0), lineWidth: 0.5)
                        )
                )
                .opacity(isFocused ? 1.0 : (isHovered ? 0.85 : 0.55))

        case .underline:
            content
                .overlay(alignment: .bottom) {
                    if isFocused {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(accentColor)
                            .frame(width: 16, height: 2.5)
                            .offset(y: -2)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .opacity(isFocused ? 1.0 : (isHovered ? 0.85 : 0.55))

        case .glow:
            content
                .shadow(color: isFocused ? accentColor.opacity(0.6) : .clear, radius: isFocused ? 6 : 0)
                .opacity(isFocused ? 1.0 : (isHovered ? 0.85 : 0.5))

        case .inverted:
            if isFocused {
                content
                    .background(
                        Capsule()
                            .fill(accentColor)
                    )
                    .foregroundStyle(accentColor.inverted())
                    .opacity(1.0)
            } else {
                content
                    .opacity(isHovered ? 0.9 : 0.6)
            }
        }
    }
}

private extension View {
    func highlightStyle(
        _ style: SpacesHighlight,
        isFocused: Bool,
        isHovered: Bool,
        accentColor: Color
    ) -> some View {
        modifier(HighlightModifier(
            style: style,
            isFocused: isFocused,
            isHovered: isHovered,
            accentColor: accentColor
        ))
    }
}

// MARK: - Window View (icon + optional title)

private struct WindowView: View {
    @EnvironmentObject var configProvider: ConfigProvider
    @EnvironmentObject var viewModel: SpacesViewModel
    @Environment(\.appearance) private var appearance

    var config: ConfigData { configProvider.config }
    var windowConfig: ConfigData { config["window"]?.dictionaryValue ?? [:] }
    var titleConfig: ConfigData {
        windowConfig["title"]?.dictionaryValue ?? [:]
    }

    var showTitle: Bool { windowConfig["show-title"]?.boolValue ?? true }
    var maxLength: Int { titleConfig["max-length"]?.intValue ?? 50 }
    var alwaysDisplayAppTitleFor: [String] { titleConfig["always-display-app-name-for"]?.arrayValue?.filter({ $0.stringValue != nil }).map { $0.stringValue! } ?? [] }
    var tintIcons: Bool { config["space.tint-icons"]?.boolValue ?? false }
    var iconStyle: IconStyle {
        guard let raw = config["space.icon-style"]?.stringValue else { return .appIcon }
        return IconStyle(rawValue: raw) ?? .appIcon
    }

    let window: AnyWindow
    let space: AnySpace

    @State var isHovered = false

    var body: some View {
        let titleMaxLength = maxLength
        let size: CGFloat = 21
        let sameAppCount = space.windows.filter { $0.appName == window.appName }
            .count
        let title = sameAppCount > 1 && !alwaysDisplayAppTitleFor.contains { $0 == window.appName } ? window.title : (window.appName ?? "")
        let spaceIsFocused = space.windows.contains { $0.isFocused }
        HStack {
            ZStack {
                if iconStyle == .sfSymbol, let symbolName = AppIconMapper.symbolName(for: window.appName) {
                    // Use SF Symbol
                    Image(systemName: symbolName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: size * 0.7, height: size * 0.7)
                        .foregroundStyle(appearance.foregroundColor)
                        .shadow(
                            color: .black.opacity(0.3),
                            radius: 2
                        )
                } else if let icon = window.appIcon {
                    if tintIcons {
                        // Render as template with foreground color tint
                        Image(nsImage: icon.tinted(with: appearance.foregroundColor))
                            .resizable()
                            .frame(width: size, height: size)
                            .shadow(
                                color: .black.opacity(0.3),
                                radius: 2
                            )
                    } else {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: size, height: size)
                            .shadow(
                                color: .black.opacity(0.3),
                                radius: 2
                            )
                    }
                } else {
                    Image(systemName: "questionmark.circle")
                        .resizable()
                        .frame(width: size, height: size)
                }
            }
            .opacity(spaceIsFocused && !window.isFocused ? 0.5 : 1)
            .transition(.blurReplace)

            if window.isFocused, !title.isEmpty, showTitle {
                HStack {
                    Text(
                        title.count > titleMaxLength
                            ? String(title.prefix(titleMaxLength)) + "..."
                            : title
                    )
                    .widgetFontStyle()
                    .fixedSize(horizontal: true, vertical: false)
                    .shadow(color: .black.opacity(0.3), radius: 3)
                    .fontWeight(.semibold)
                    Spacer().frame(width: 5)
                }
                .transition(.blurReplace)
            }
        }
        .padding(.all, 1)
        .background(isHovered || (!showTitle && window.isFocused) ? .selected : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .animation(.smooth, value: isHovered)
        .frame(height: 30)
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.switchToSpace(space)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                viewModel.switchToWindow(window)
            }
        }
        .onHover { value in
            isHovered = value
        }
    }
}
