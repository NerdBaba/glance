# Spaces Widget — Pacman Icons & Custom SF Pro Icon Picker

**Date:** 2026-04-12
**Author:** Qoder
**Status:** Draft

## Overview

Extend the Glance Spaces widget with two new display modes (Pacman icons, custom SF Pro symbols), a composable display element system (number, name, icon toggles with per-space ordering), and a full visual icon picker in settings.

## Architecture

### SpaceContentRenderer Protocol

```swift
protocol SpaceContentRenderer: Identifiable {
    var id: String { get }
    var displayName: String { get }
    func render(space: AnySpace, isFocused: Bool, config: ConfigData) -> some View
    static func defaultConfig() -> [String: TOMLValue]
}
```

Each display mode is a conformer. The `SpaceRendererRegistry` discovers and instantiates active renderers based on config. New display modes require zero changes to the rendering pipeline — just a new conformer.

### Renderer Implementations

| Renderer | ID | Source |
|----------|----|--------|
| `DotsRenderer` | `"dots"` | Refactored from existing `dotsContent()` |
| `NumbersRenderer` | `"numbers"` | Refactored from existing `numbersContent()` |
| `IconsRenderer` | `"icons"`, `"icons-only"`, `"focused-only"` | Refactored from existing `iconsContent()`, `iconsOnlyContent()`, `focusedOnlyContent()` |
| `PacmanRenderer` | `"pacman"` | NEW — Pacman shape with direction tracking |
| `CustomIconRenderer` | `"custom-icons"` | NEW — SF Pro symbol from config |

### ComposedSpaceView

Wraps renderer output with independently toggleable elements:
- **Number** — controlled by `space.show-number`, formatted via `space.numeral-system`
- **Name** — controlled by `space.show-name`, shows workspace name
- **Icon** — controlled by `space.show-icon`, from renderer output

Element order is configurable globally via `space.element-order` and overridden per-space via `space.per-space-config[].order`.

## TOML Schema

```toml
[widgets.default.spaces]
space.display-mode = "pacman"  # extended enum: dots, numbers, icons, icons-only, focused-only, pacman, custom-icons

# Composable display elements (global defaults)
space.show-number = true
space.show-name = false
space.show-icon = true
space.element-order = ["icon", "number", "name"]

# Per-space overrides
space.per-space-config = [
    { id = "1", show-number = true, show-name = true, show-icon = true, icon = "gamecontroller", order = ["icon", "number", "name"] },
    { id = "2", show-number = true, show-name = false, show-icon = true, icon = "browser", order = ["icon", "number"] }
]

# Global icon (when not using per-space)
space.global-icon = "desktopcomputer"

# Pacman settings
space.pacman.size = 10.0
space.pacman.animate-direction = true

# Numeral system (matches existing convention: arabic, arabicIndic, japanese)
space.numeral-system = "arabicIndic"  # arabic, arabicIndic, japanese

# Icon picker recent history (auto-populated by app when user selects icons in settings)
space.recent-icons = ["gamecontroller", "browser", "terminal", "music.note", "gear", "star"]
```

## Pacman Renderer

- Renders a Pacman shape using SwiftUI `Shape` (arc path with mouth angle)
- Focused space: mouth open (~45 degree angle), facing direction of travel
- Inactive spaces: mouth closed (full circle) or smaller Pacman
- Direction determined by comparing current focused space index to `UserDefaults` key `glance.spaces.lastFocusedIndex`
- First launch (no history): defaults to facing right
- Configurable size via `space.pacman.size`

## Custom Icon Renderer

- Reads `space.global-icon` or per-space `icon` from `space.per-space-config`
- Renders `Image(systemName: symbolName)` at configured size
- Supports tinting via existing `space.tint-icons` config
- Invalid symbol name falls back to `questionmark.circle`

## Icon Picker Settings UI

### IconPickerView (reusable component)
- Curated grid of ~150 SF Symbols in `LazyVGrid` (5 columns)
- Search bar at top — filters full SF Symbol library
- "Recent" row showing last 6 chosen icons from `space.recent-icons`
- Tap to select — highlights with accent border
- Returns selected symbol name as `String?`

### PerSpaceIconConfigView
- List of spaces with current icon assignment
- Each row: `[icon preview] [space name/number] [change button]`
- "Change" opens `IconPickerView` as a sheet
- Toggle: "Use same icon for all spaces" vs "Custom icon per space"

### DisplayElementsConfigView
- Toggle switches: "Show Number", "Show Name", "Show Icon"
- Drag-reorderable list for element order (only enabled elements)
- Per-space override toggle: "Customize per space"

### Curated Icon Categories (~150 symbols)
- **Desktop:** desktopcomputer, laptopcomputer, server.rack
- **Apps:** app, browser, terminal, gearshape, music.note
- **Communication:** bubble.left, phone, envelope
- **Work:** briefcase, hammer, wrench, square.grid.3x3
- **Media:** play.circle, camera, mic, speaker.wave.3
- **System:** wifi, battery.100, sun.max, moon, star
- **Navigation:** location, map, globe, house
- **Generic:** circle.fill, square.fill, triangle.fill, star.fill
- **Pacman:** pacman (custom shape, not SF Symbol)

## Data Flow

```
TOML config → ConfigManager → SpacesWidget
                                    ↓
                          SpaceRendererRegistry
                                    ↓
                    Select renderer by display-mode
                                    ↓
                    ComposedSpaceView arranges elements
                                    ↓
                    User clicks space → switchToSpace()

User changes settings → configManager.updateConfigValue()
                                    ↓
                        TOML file written
                                    ↓
                    Config file watcher triggers reload
                                    ↓
                    SpacesWidget re-renders with new config
```

## Error Handling

| Scenario | Behavior |
|----------|----------|
| Invalid SF Symbol name | Falls back to `questionmark.circle` with log warning |
| Per-space config missing space ID | Falls back to global icon/settings |
| TOML parse error on new keys | Lenient parser ignores unknown keys, uses defaults |
| Icon picker sheet dismissed without selection | No change to config |
| Recent icons empty/corrupt | Shows empty recent row, grid still works |
| Direction tracking unavailable (first launch) | Pacman faces right by default |

## Migration

Existing configs continue to work unchanged. `ComposedSpaceView` defaults to `space.element-order = ["number"]` for backward compatibility with existing configs that don't have element toggles. No data migration needed.

### Per-Space ID Resolution

Space IDs in `per-space-config` match the `AnySpace.id` field:
- **Native/yabai:** Numeric string (`"1"`, `"2"`, `"3"`)
- **AeroSpace:** Workspace name string (`"dev"`, `"browser"`, `"chat"`)

The config matching is string-based, so it works with both. For native/yabai, the ID is stable across reboots. For AeroSpace, the workspace name is the stable identifier.

## File Structure

```
Glance/Widgets/Spaces/
├── Renderers/
│   ├── SpaceContentRenderer.swift          # Protocol + registry
│   ├── DotsRenderer.swift                  # Refactored from existing
│   ├── NumbersRenderer.swift               # Refactored from existing
│   ├── IconsRenderer.swift                 # Refactored from existing
│   ├── PacmanRenderer.swift                # NEW
│   └── CustomIconRenderer.swift            # NEW
├── Views/
│   ├── ComposedSpaceView.swift             # NEW — element composition
│   ├── PacmanShape.swift                   # NEW — SwiftUI Shape
│   └── SpaceElementBuilder.swift           # NEW — builds number/name/icon views
├── Config/
│   └── SpacesIconConfig.swift              # NEW — per-space config model
├── SpacesWidget.swift                      # Modified — uses registry
├── SpacesViewModel.swift                   # Unchanged
└── SpacesModels.swift                      # Unchanged

Glance/Settings/
├── Tabs/
│   └── SpacesSettingsTab.swift             # Modified — adds icon picker sections
└── Components/
    ├── IconPickerView.swift                # NEW — SF Symbol picker
    ├── PerSpaceIconConfigView.swift        # NEW — per-space icon assignment
    └── DisplayElementsConfigView.swift     # NEW — element toggle/order
```

## Performance

- Icon picker grid uses `LazyVGrid` for lazy loading
- SF Symbol images are cached by the system
- Per-space config read once per render cycle from in-memory `ConfigData`
- No new polling — uses existing 1s timer + event-driven refresh
- Direction tracking via `UserDefaults` (negligible cost)
