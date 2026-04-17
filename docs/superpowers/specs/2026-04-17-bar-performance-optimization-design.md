# Glance Bar Performance Optimization — Design Spec

**Date:** 2026-04-17
**Author:** Qoder
**Status:** Draft

## Problem Statement

Glance's status bar uses excessive CPU for a background utility. A resource monitor report identified:

1. **SwiftUI layout thrashing** — Main thread busy in `StackLayout.sizeThatFits` and `ViewGraph.renderDisplayList` on every data tick
2. **Expensive text rendering** — `CoreGraphics` `RB::Coverage::Glyphs::fill` and `CA::Transaction::commit()` firing constantly
3. **Redundant shadow passes** — 41 `.shadow()` calls across 24 files, each a separate CoreGraphics render pass
4. **GeometryReader overhead** — `GeometryReader` inside `.background()` triggers layout computation on every frame
5. **No delta-based publishing** — `@Published` fires on every tick even when values changed insignificantly

Target: Reduce idle CPU from noticeable to near-zero for a menu bar utility.

---

## Optimization 1: Delta-Based Publishing for SystemMonitor

**File:** `Glance/Widgets/SystemMonitor/SystemMonitorViewModel.swift`

**Current:** Timer fires every 3s, reads CPU/memory, assigns directly to `@Published` properties. SwiftUI re-renders every subscriber regardless of change magnitude.

**Change:** Add a `publishThreshold` check. Only update `@Published` properties when the delta exceeds a meaningful amount:

- CPU: 1% threshold
- Memory: 0.1GB threshold
- Memory pressure: only on state change ("Normal" → "Warning")

This eliminates micro-updates that users can't perceive but SwiftUI still renders.

**Implementation:**
- Store `lastPublishedCPU` and `lastPublishedMemory` as private `Double`
- In `update()`, compute new values, compare against last published, only assign if delta exceeds threshold

---

## Optimization 2: Fixed Frame Widths on Volatile Text

**Files:** All widget files with dynamic text (SystemMonitorWidget, TimeWidget, BatteryWidget, NetworkWidget, EnergyWidget, FanWidget, TemperatureWidget, DiskWidget, BluetoothWidget, ScriptWidget, ClipboardWidget, PomodoroWidget, BrightnessWidget, VolumeWidget, InputLanguageWidget, ActiveAppWidget, WeatherWidget, SpacesWidget, NowPlayingWidget)

**Current:** Text elements like `Text(String(format: "%.0f%%", cpuUsage))` change intrinsic width when digit count changes ("9%" → "10%" → "100%"), triggering `StackLayout.sizeThatFits` recursion across the parent HStack.

**Change:** Apply `.frame(width: W, alignment: .trailing)` on volatile text elements with a fixed width sufficient for the maximum expected string. Combined with existing `.monospacedDigit()`, this prevents SwiftUI from recalculating layout when content changes.

**Width guidelines:**
- CPU percentage ("100%"): ~40pt
- Memory ("99.9G"): ~55pt
- Time ("Wed 17 Apr, 23:59"): variable, keep as-is with monospaced digits

Only apply to widgets where the text width actually changes during normal operation.

---

## Optimization 3: Shadow Consolidation

**Files:** All 24 files with `.shadow(color: .black.opacity(0.3), radius: 3)` calls

**Current:** Every widget independently applies `.shadow(color: .black.opacity(0.3), radius: 3)`. The `WidgetStyleModifier` already applies glow + shadow at the container level for islands/pills/floating formations. Individual widget shadows are visually redundant and each triggers a separate CoreGraphics pass.

**Change:** Remove `.shadow(color: .black.opacity(0.3), radius: 3)` from all individual widgets. The container-level shadow from `WidgetStyleModifier` provides sufficient depth. Keep `.shadow()` calls that serve a distinct visual purpose (e.g., glow effects, colored shadows).

**Exception:** `BarStyleProvider.swift` shadow calls in `WidgetStyleModifier` and `PopupStyleModifier` are kept — these are the container-level shadows that replace the per-widget ones.

---

## Optimization 4: GeometryReader Elimination

**Files:** TimeWidget, SystemMonitorWidget, and other widgets using `GeometryReader` in `.background()` for popup rect capture

**Current:** Multiple widgets use:
```swift
.background(
    GeometryReader { geo in
        Color.clear
            .onAppear { rect = geo.frame(in: .global) }
            .onChange(of: geo.frame(in: .global)) { _, newValue in rect = newValue }
    }
)
```
This fires on every layout pass, not just when the rect actually changes.

**Change:** Replace with an `onAppear`-only approach. The popup rect rarely changes after initial layout — it only changes if the window moves or the bar reconfigures. Capture the rect once on appear and on config changes, not on every frame.

**Implementation:**
- Remove `.onChange(of: geometry.frame(in: .global))`
- Keep only `.onAppear` capture
- Add a notification observer for `NSWindow.didMoveNotification` to recapture if the window moves

---

## Optimization 5: Config Read Caching in MenuBarView

**File:** `Glance/Views/MenuBarView.swift`, `Glance/Utils/ExperimentalConfigurationModifier.swift`

**Current:** `ExperimentalConfigurationModifier` reads `@ObservedObject var configManager` inside every widget's modifier chain. Each widget independently resolves formation, height, and padding values from the config on every render pass.

**Change:** Resolve `ForegroundConfig` values once in `MenuBarView` and pass them down as environment values or plain `let` parameters to child widgets. This eliminates N redundant config reads per render cycle (where N = number of widgets).

**Implementation:**
- Add a new `@Environment` key for resolved widget formation config
- `MenuBarView` sets this environment value once
- `ExperimentalConfigurationModifier` reads from environment instead of `ConfigManager.shared`

---

## Scope & Constraints

- **No architectural changes:** Keep SwiftUI, keep existing view hierarchy
- **No behavior changes:** Visual output must remain identical
- **All 4 formations optimized:** full, floating, islands, pills
- **Backward compatible:** Config file format unchanged
- **Style files untouched:** Glass/Solid/Minimal rendering logic unchanged

---

## Risk Assessment

| Risk | Likelihood | Mitigation |
|---|---|---|
| Fixed-width text clipping on edge cases | Low | Use generous width bounds, test with max values |
| Popup positioning slightly off after GeometryReader removal | Low | Test with all formations, fall back to onAppear + window move notification |
| Delta threshold too aggressive (updates feel laggy) | Medium | Start conservative (1% CPU, 0.1GB RAM), adjustable |
| Environment key conflicts with existing keys | Low | Use private key types, no naming overlap |
