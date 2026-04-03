# Glance Typography System

## Overview

This document describes how fonts and text are implemented in the Glance status bar application.

## Current Implementation

### Hardcoded Font Sizes

Each widget in Glance hardcodes its own font configuration using SwiftUI's system font. There is **no global typography configuration** or theming system for fonts.

**Common Pattern:**
```swift
Text(viewModel.appName)
    .font(.system(size: 13, weight: .medium))
    .lineLimit(1)
```

### Standard Font Sizes

| Size | Weight | Usage |
|------|--------|-------|
| 10pt | regular | Secondary info, badges |
| 11pt | medium/semibold | Small labels, Bluetooth widget |
| 12pt | medium | Temperature, Pomodoro widgets |
| 13pt | medium/semibold | **Primary widget text** (ActiveApp, Weather) |
| 14pt | regular/semibold | Popup headers |
| 20pt | semibold | Large timers (Pomodoro) |

### Common Font Weights

- `.regular` - Body text, secondary information
- `.medium` - Primary widget labels
- `.semibold` - Emphasized text, headers
- `.bold` - Rarely used

### Text Modifiers

Widgets commonly use these modifiers:

```swift
// Monospaced digits for numbers/time
Text(timeString)
    .monospacedDigit()

// Prevent text wrapping
Text(longString)
    .lineLimit(1)

// Add shadow for readability
Text(label)
    .shadow(color: .black.opacity(0.3), radius: 3)

// Separate weight from base font
Text(title)
    .fontWeight(.semibold)
    .font(.headline)
```

## Widget Examples

### ActiveAppWidget
```swift
Text(viewModel.appName)
    .font(.system(size: 13, weight: .medium))
    .lineLimit(1)
```

### TimeWidget
```swift
VStack(alignment: .trailing, spacing: 0) {
    Text(formattedTime(pattern: format, from: currentTime))
        .fontWeight(.semibold)
    if let event = calendarManager.nextEvent, calendarShowEvents {
        Text(eventText(for: event))
            .opacity(0.8)
            .font(.subheadline)
    }
}
.font(.headline)
.monospacedDigit()
```

### WeatherWidget
```swift
HStack(spacing: 4) {
    Text("\(temperature)°")
        .font(.system(size: 13, weight: .medium))
    Image(systemName: weatherIcon)
        .font(.system(size: 12))
}
```

## Configuration System

### AppearanceConfig

Located in `Glance/Config/AppearanceConfig.swift`

The `AppearanceConfig` struct contains visual properties but **does NOT include typography**:

```swift
struct AppearanceConfig {
    // Colors
    var foregroundColor: Color
    var accentColor: Color
    var widgetBackgroundColor: Color
    var borderColor: Color
    var glowColor: Color
    
    // Borders & Shadows
    var borderWidth: CGFloat
    var borderTopOpacity: Double
    var glowOpacity: Double
    var shadowOpacity: Double
    var shadowRadius: CGFloat
    
    // Layout
    var roundness: Double
    var renderingStyle: BarStyle
    
    // ❌ NO font properties
}
```

### Preset System

Glance has 11 built-in presets defined in `PresetRegistry.swift`:
- liquid-glass, frosted, flat-dark, minimal, neon
- tokyo-night, dracula, gruvbox, nord, catppuccin, solarized

Presets define colors and visual effects but **do not configure typography**.

### TOML Config

Users can customize appearance via `~/.glance-config.toml`:

```toml
[appearance]
roundness = 50
border-width = 1.0
foreground-color = "#ffffff"
accent-color = "#007AFF"
# ... other visual properties

# ❌ No font configuration available
```

## Style System

### BarStyleProvider Protocol

```swift
protocol BarStyleProvider {
    func widgetBackground(cornerRadius: CGFloat) -> AnyView
    func popupBackground(cornerRadius: CGFloat) -> AnyView
    func hoverBrightness(isHovered: Bool) -> Double
    func focusOpacity(isFocused: Bool) -> Double
}
```

Styles control backgrounds and effects, **not typography**.

### Available Styles

- `.glass` - Blur + gradient border
- `.solid` - Flat opaque background  
- `.minimal` - Transparent, text/icons only

## File Locations

| Component | File Path |
|-----------|-----------|
| Appearance Config | `Glance/Config/AppearanceConfig.swift` |
| Style Protocol | `Glance/Styles/BarStyleProvider.swift` |
| Preset Registry | `Glance/Config/PresetRegistry.swift` |
| Widget Implementations | `Glance/Widgets/*/*.swift` |

## Future Enhancement Opportunities

Potential typography improvements:

1. **Global Font Scale** - Add `fontSizeMultiplier` to AppearanceConfig
2. **Config-based Fonts** - Allow font size/weight customization in TOML
3. **Custom Fonts** - Support loading custom SF Pro variants or third-party fonts
4. **Typography Presets** - Include font settings in visual presets
5. **Accessibility** - Respect system font size preferences via `.dynamicTypeSize()`

## Summary

**Current State:**
- ✅ Colors, borders, shadows fully configurable
- ✅ 11 visual presets available
- ❌ Fonts hardcoded per-widget
- ❌ No global typography system
- ❌ No config support for fonts
- ❌ No custom font support

**Font decisions are made at the widget level, not the app level.**
