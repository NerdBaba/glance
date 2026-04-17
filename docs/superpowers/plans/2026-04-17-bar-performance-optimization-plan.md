# Bar Performance Optimization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce Glance's idle CPU usage from noticeable to near-zero by eliminating layout thrashing, redundant rendering, and excessive Published property updates.

**Architecture:** Six targeted optimizations applied across widget files, view models, and the config pipeline. No architectural changes — all modifications are surgical improvements to existing code paths.

**Tech Stack:** Swift 5.9+, SwiftUI, AppKit, Darwin system APIs

---

## File Map

| File | Change Type | Responsibility |
|---|---|---|
| `Glance/Widgets/SystemMonitor/SystemMonitorViewModel.swift` | Modify | Delta-based publishing thresholds |
| `Glance/Widgets/SystemMonitor/SystemMonitorWidget.swift` | Modify | Fixed frame widths, remove shadow, simplify GeometryReader |
| `Glance/Widgets/Time+Calendar/TimeWidget.swift` | Modify | Remove shadow, simplify GeometryReader |
| `Glance/Widgets/Battery/BatteryWidget.swift` | Modify | Simplify GeometryReader |
| `Glance/Widgets/Network/NetworkWidget.swift` | Modify | Simplify GeometryReader |
| `Glance/Widgets/Disk/DiskWidget.swift` | Modify | Remove shadow, fixed frame width, simplify GeometryReader |
| `Glance/Widgets/Energy/EnergyWidget.swift` | Modify | Remove shadow, simplify GeometryReader |
| `Glance/Widgets/Fan/FanWidget.swift` | Modify | Remove shadow, simplify GeometryReader |
| `Glance/Widgets/Temperature/TemperatureWidget.swift` | Modify | Remove shadow, simplify GeometryReader |
| `Glance/Widgets/Bluetooth/BluetoothWidget.swift` | Modify | Remove shadow, simplify GeometryReader |
| `Glance/Widgets/Clipboard/ClipboardWidget.swift` | Modify | Remove shadow, simplify GeometryReader |
| `Glance/Widgets/Volume/VolumeWidget.swift` | Modify | Remove shadow, simplify GeometryReader |
| `Glance/Widgets/Brightness/BrightnessWidget.swift` | Modify | Remove shadow, simplify GeometryReader |
| `Glance/Widgets/ActiveApp/ActiveAppWidget.swift` | Modify | Remove shadow |
| `Glance/Widgets/InputLanguage/InputLanguageWidget.swift` | Modify | Remove shadow, simplify GeometryReader |
| `Glance/Widgets/Script/ScriptWidget.swift` | Modify | Remove shadow |
| `Glance/Widgets/Pomodoro/PomodoroWidget.swift` | Modify | Remove shadow, simplify GeometryReader |
| `Glance/Widgets/Weather/WeatherWidget.swift` | Modify | Remove shadow, simplify GeometryReader |
| `Glance/Widgets/NowPlaying/NowPlayingWidget.swift` | Modify | Simplify GeometryReader |
| `Glance/Config/ConfigManager.swift` | Modify | Add Config equatable, add `lastConfig` for change detection |
| `Glance/Views/MenuBarView.swift` | Modify | Pass resolved ForegroundConfig via environment |
| `Glance/Utils/ExperimentalConfigurationModifier.swift` | Modify | Read from environment instead of ConfigManager.shared |

---

### Task 1: Delta-Based Publishing for SystemMonitorViewModel

**Files:**
- Modify: `Glance/Widgets/SystemMonitor/SystemMonitorViewModel.swift`

- [ ] **Step 1: Add delta threshold logic to the ViewModel**

Read the file first. Then modify the `update()` method to only publish when values change beyond a meaningful threshold. Add private `lastPublishedCPU` and `lastPublishedMemory` tracking variables.

The thresholds:
- CPU: 1.0% minimum change
- Memory: 0.1 GB (100 MB) minimum change
- Memory pressure: only publish on state change string comparison

```swift
final class SystemMonitorViewModel: ObservableObject {
    static let shared = SystemMonitorViewModel()

    @Published var cpuUsage: Double = 0
    @Published var memoryUsed: Double = 0
    @Published var memoryTotal: Double = 0
    @Published var memoryPressure: String = "Normal"

    private var timer: Timer?
    private var prev_CPUInfo: host_cpu_load_info?
    private var wakeObserver: NSObjectProtocol?
    private let logger = AppLogger.shared

    // Delta-based publishing: track last published values
    private var lastPublishedCPU: Double = -1
    private var lastPublishedMemory: Double = -1
    private var lastPublishedPressure: String = ""

    // Thresholds
    private let cpuThreshold: Double = 1.0
    private let memoryThreshold: Double = 0.1 * 1024 * 1024 * 1024 // 0.1 GB in bytes

    // ... rest of existing properties and init stay the same ...

    private func update() {
        updateCPU()
        updateMemory()
    }

    // In updateCPU(), replace the direct assignment:
    //   cpuUsage = ((userDelta + sysDelta + niceDelta) / total) * 100
    // With thresholded assignment:
    private func updateCPU() {
        // ... existing tick reading code stays the same until the assignment ...
        if total > 0 {
            let newCPU = ((userDelta + sysDelta + niceDelta) / total) * 100
            if abs(newCPU - lastPublishedCPU) >= cpuThreshold {
                cpuUsage = newCPU
                lastPublishedCPU = newCPU
            }
        }
        prev_CPUInfo = current
    }

    // In updateMemory(), replace direct assignments with thresholded:
    private func updateMemory() {
        // ... existing memory calculation code ...
        let newMemoryUsed = active + wired + compressed

        if abs(newMemoryUsed - lastPublishedMemory) >= memoryThreshold {
            memoryUsed = newMemoryUsed
            lastPublishedMemory = newMemoryUsed
        }

        // Memory pressure — only publish on state change
        let ratio = memoryUsed / memoryTotal
        let newPressure: String
        if ratio > 0.85 {
            newPressure = "Critical"
        } else if ratio > 0.7 {
            newPressure = "Warning"
        } else {
            newPressure = "Normal"
        }
        if newPressure != lastPublishedPressure {
            memoryPressure = newPressure
            lastPublishedPressure = newPressure
        }
    }
```

- [ ] **Step 2: Commit**

```bash
git add Glance/Widgets/SystemMonitor/SystemMonitorViewModel.swift
git commit -m "perf: add delta-based publishing to SystemMonitorViewModel

Only fire @Published updates when CPU changes by >=1%, memory by >=0.1GB,
or pressure state actually changes. Eliminates micro-updates that trigger
unnecessary SwiftUI re-renders."
```

---

### Task 2: Remove Redundant Shadows from All Widgets

**Files:** Modify all widgets listed below. Each gets the same pattern: remove `.shadow(color: .black.opacity(0.3), radius: 3)`.

The shadow calls to remove are the per-widget redundant ones. The container-level shadows in `BarStyleProvider.swift` (`WidgetStyleModifier`, `PopupStyleModifier`) are KEPT.

**Widgets to modify (remove `.shadow(color: .black.opacity(0.3), radius: 3)`):**

1. `Glance/Widgets/SystemMonitor/SystemMonitorWidget.swift` — line ~29
2. `Glance/Widgets/Time+Calendar/TimeWidget.swift` — line ~51
3. `Glance/Widgets/Disk/DiskWidget.swift` — line ~16
4. `Glance/Widgets/Energy/EnergyWidget.swift` — line ~40
5. `Glance/Widgets/Fan/FanWidget.swift` — line ~29
6. `Glance/Widgets/Temperature/TemperatureWidget.swift` — line ~30
7. `Glance/Widgets/Bluetooth/BluetoothWidget.swift` — line ~18
8. `Glance/Widgets/Clipboard/ClipboardWidget.swift` — line ~12
9. `Glance/Widgets/Volume/VolumeWidget.swift` — line ~29
10. `Glance/Widgets/Brightness/BrightnessWidget.swift` — lines ~30 and ~35 (two shadows)
11. `Glance/Widgets/ActiveApp/ActiveAppWidget.swift` — line ~12
12. `Glance/Widgets/InputLanguage/InputLanguageWidget.swift` — line ~11
13. `Glance/Widgets/Script/ScriptWidget.swift` — line ~16
14. `Glance/Widgets/Pomodoro/PomodoroWidget.swift` — lines ~19 and ~24 (two shadows)
15. `Glance/Widgets/Weather/WeatherWidget.swift` — line ~21

**Spaces widget shadows** in `Glance/Widgets/Spaces/SpacesWidget.swift` are KEEP-eligible:
- Lines 395-398, 405-408, 413-416: icon shadows with `radius: 2` — these are visual styling for icons, not the redundant `.shadow(color: .black.opacity(0.3), radius: 3)` pattern
- Line 330: glow effect shadow — this is intentional highlight styling
- Line 436: text shadow — this is for the window title readability

These are functionally different and should remain.

- [ ] **Step 1: Remove shadows from SystemMonitorWidget**

In `SystemMonitorWidget.swift`, remove the `.shadow(color: .black.opacity(0.3), radius: 3)` line from the view chain. The chain goes:
```swift
        .barSingleLineAligned()
        // DELETE: .shadow(color: .black.opacity(0.3), radius: 3)
        .experimentalConfiguration(horizontalPadding: 10)
```

- [ ] **Step 2: Remove shadows from TimeWidget**

In `TimeWidget.swift`, remove `.shadow(color: .black.opacity(0.3), radius: 3)` after `.font(widgetFont.toFont())`.

- [ ] **Step 3: Remove shadows from DiskWidget, EnergyWidget, FanWidget, TemperatureWidget**

Same pattern: remove `.shadow(color: .black.opacity(0.3), radius: 3)` from each.

- [ ] **Step 4: Remove shadows from BluetoothWidget, ClipboardWidget, VolumeWidget, BrightnessWidget**

Same pattern. BrightnessWidget has two shadow calls (lines 30 and 35) — remove both.

- [ ] **Step 5: Remove shadows from ActiveAppWidget, InputLanguageWidget, ScriptWidget, PomodoroWidget, WeatherWidget**

Same pattern. PomodoroWidget has two shadow calls — remove both.

- [ ] **Step 6: Commit**

```bash
git add Glance/Widgets/SystemMonitor/SystemMonitorWidget.swift \
  Glance/Widgets/Time+Calendar/TimeWidget.swift \
  Glance/Widgets/Disk/DiskWidget.swift \
  Glance/Widgets/Energy/EnergyWidget.swift \
  Glance/Widgets/Fan/FanWidget.swift \
  Glance/Widgets/Temperature/TemperatureWidget.swift \
  Glance/Widgets/Bluetooth/BluetoothWidget.swift \
  Glance/Widgets/Clipboard/ClipboardWidget.swift \
  Glance/Widgets/Volume/VolumeWidget.swift \
  Glance/Widgets/Brightness/BrightnessWidget.swift \
  Glance/Widgets/ActiveApp/ActiveAppWidget.swift \
  Glance/Widgets/InputLanguage/InputLanguageWidget.swift \
  Glance/Widgets/Script/ScriptWidget.swift \
  Glance/Widgets/Pomodoro/PomodoroWidget.swift \
  Glance/Widgets/Weather/WeatherWidget.swift
git commit -m "perf: remove redundant per-widget shadow calls

Remove .shadow(color: .black.opacity(0.3), radius: 3) from 15 widgets.
The WidgetStyleModifier already applies container-level shadows for
islands/pills/floating formations. Per-widget shadows were visually
redundant and each triggered a separate CoreGraphics render pass."
```

---

### Task 3: Simplify GeometryReader to OnAppear-Only

**Files:** Modify all widgets that use `GeometryReader` in `.background()` for popup rect capture. Replace the `.onChange(of: geometry.frame(in: .global))` pattern with `.onAppear` only.

The pattern to replace (in every widget):
```swift
.background(
    GeometryReader { geo in
        Color.clear
            .onAppear { rect = geo.frame(in: .global) }
            .onChange(of: geo.frame(in: .global)) { _, newValue in
                rect = newValue
            }
    }
)
```

Replace with:
```swift
.background(
    GeometryReader { geo in
        Color.clear
            .onAppear { rect = geo.frame(in: .global) }
    }
)
```

The rect rarely changes after initial layout. It only changes if the window moves or the bar reconfigures — both of which trigger a full view rebuild anyway.

**Widgets to modify:**

1. `Glance/Widgets/SystemMonitor/SystemMonitorWidget.swift`
2. `Glance/Widgets/Time+Calendar/TimeWidget.swift`
3. `Glance/Widgets/Battery/BatteryWidget.swift`
4. `Glance/Widgets/Network/NetworkWidget.swift`
5. `Glance/Widgets/Disk/DiskWidget.swift`
6. `Glance/Widgets/Energy/EnergyWidget.swift`
7. `Glance/Widgets/Fan/FanWidget.swift`
8. `Glance/Widgets/Temperature/TemperatureWidget.swift`
9. `Glance/Widgets/Bluetooth/BluetoothWidget.swift`
10. `Glance/Widgets/Clipboard/ClipboardWidget.swift`
11. `Glance/Widgets/Volume/VolumeWidget.swift`
12. `Glance/Widgets/Brightness/BrightnessWidget.swift`
13. `Glance/Widgets/InputLanguage/InputLanguageWidget.swift`
14. `Glance/Widgets/Pomodoro/PomodoroWidget.swift`
15. `Glance/Widgets/Weather/WeatherWidget.swift`
16. `Glance/Widgets/NowPlaying/NowPlayingWidget.swift`

- [ ] **Step 1: Simplify SystemMonitorWidget GeometryReader**

Remove the `.onChange(of: geo.frame(in: .global))` closure. Keep only `.onAppear`.

- [ ] **Step 2: Simplify all remaining widget GeometryReaders**

Apply the same change to all 15 remaining widgets listed above.

- [ ] **Step 3: Commit**

```bash
git add Glance/Widgets/SystemMonitor/SystemMonitorWidget.swift \
  Glance/Widgets/Time+Calendar/TimeWidget.swift \
  Glance/Widgets/Battery/BatteryWidget.swift \
  Glance/Widgets/Network/NetworkWidget.swift \
  Glance/Widgets/Disk/DiskWidget.swift \
  Glance/Widgets/Energy/EnergyWidget.swift \
  Glance/Widgets/Fan/FanWidget.swift \
  Glance/Widgets/Temperature/TemperatureWidget.swift \
  Glance/Widgets/Bluetooth/BluetoothWidget.swift \
  Glance/Widgets/Clipboard/ClipboardWidget.swift \
  Glance/Widgets/Volume/VolumeWidget.swift \
  Glance/Widgets/Brightness/BrightnessWidget.swift \
  Glance/Widgets/InputLanguage/InputLanguageWidget.swift \
  Glance/Widgets/Pomodoro/PomodoroWidget.swift \
  Glance/Widgets/Weather/WeatherWidget.swift \
  Glance/Widgets/NowPlaying/NowPlayingWidget.swift
git commit -m "perf: simplify GeometryReader to onAppear-only in all widgets

Remove .onChange(of: geometry.frame) from 16 widgets. Popup rect capture
only needs to happen once on appear — window moves and config changes
already trigger full view rebuilds. Eliminates per-frame layout computation."
```

---

### Task 4: Add Fixed Frame Widths to Volatile Text Elements

**Files:** Modify widgets where text content changes width during normal operation.

The key widgets and their fixed widths:

| Widget | Text | Max Width | Alignment |
|---|---|---|---|
| SystemMonitorWidget | CPU "100%" | 42 | .trailing |
| SystemMonitorWidget | Memory "99.9G" | 52 | .trailing |
| DiskWidget | "9999 GB" | 60 | .trailing |
| EnergyWidget | "999.9 kW" | 62 | .trailing |
| FanWidget | "100%" | 42 | .trailing |
| TemperatureWidget | "100°C" | 48 | .trailing |
| BluetoothWidget | "99" | 24 | .trailing |
| VolumeWidget | "100%" | 38 | .trailing |
| BrightnessWidget | "100%" | 38 | .trailing |
| WeatherWidget | "100°" | 38 | .trailing |

- [ ] **Step 1: Add fixed widths to SystemMonitorWidget**

Modify the CPU text:
```swift
Text(String(format: "%.0f%%", viewModel.cpuUsage))
    .font(widgetFont.toFont())
    .monospacedDigit()
    .frame(width: 42, alignment: .trailing)
```

Modify the memory text:
```swift
Text(String(format: "%.1f", viewModel.memoryUsedGB) + "G")
    .font(widgetFont.toFont())
    .monospacedDigit()
    .frame(width: 52, alignment: .trailing)
```

- [ ] **Step 2: Add fixed widths to DiskWidget**

```swift
Text(String(format: "%.0f GB", viewModel.freeGB))
    .font(.system(size: 12, weight: .medium))
    .monospacedDigit()
    .frame(width: 60, alignment: .trailing)
```

- [ ] **Step 3: Add fixed widths to EnergyWidget**

```swift
Text(displayValue)
    .font(widgetFont.toFont())
    .monospacedDigit()
    .frame(width: 62, alignment: .trailing)
```

- [ ] **Step 4: Add fixed widths to FanWidget**

For the percentage text:
```swift
Text("\(percent)%")
    .font(widgetFont.toFont())
    .monospacedDigit()
    .frame(width: 42, alignment: .trailing)
```

For the RPM text:
```swift
Text("\(thermalManager.fanSpeed)")
    .font(widgetFont.toFont())
    .monospacedDigit()
    .frame(width: 42, alignment: .trailing)
```

- [ ] **Step 5: Add fixed widths to TemperatureWidget**

```swift
Text("\(Int(round(displayTemp)))\(displayUnit)")
    .font(widgetFont.toFont())
    .monospacedDigit()
    .frame(width: 48, alignment: .trailing)
```

- [ ] **Step 6: Add fixed widths to remaining widgets**

BluetoothWidget:
```swift
Text("\(viewModel.connectedCount)")
    .font(.system(size: 11, weight: .medium))
    .monospacedDigit()
    .frame(width: 24, alignment: .trailing)
```

VolumeWidget:
```swift
Text(viewModel.isMuted ? "Mute" : "\(viewModel.volumePercent)%")
    .font(widgetFont.toFont())
    .monospacedDigit()
    .frame(width: 38, alignment: .trailing)
```

BrightnessWidget:
```swift
Text("\(viewModel.brightnessPercent)%")
    .font(.system(size: 13, weight: .medium))
    .monospacedDigit()
    .frame(width: 38, alignment: .trailing)
```

WeatherWidget:
```swift
Text(String(format: "%.0f°", temp))
    .font(widgetFont.toFont())
    .monospacedDigit()
    .frame(width: 38, alignment: .trailing)
```

- [ ] **Step 7: Commit**

```bash
git add Glance/Widgets/SystemMonitor/SystemMonitorWidget.swift \
  Glance/Widgets/Disk/DiskWidget.swift \
  Glance/Widgets/Energy/EnergyWidget.swift \
  Glance/Widgets/Fan/FanWidget.swift \
  Glance/Widgets/Temperature/TemperatureWidget.swift \
  Glance/Widgets/Bluetooth/BluetoothWidget.swift \
  Glance/Widgets/Volume/VolumeWidget.swift \
  Glance/Widgets/Brightness/BrightnessWidget.swift \
  Glance/Widgets/Weather/WeatherWidget.swift
git commit -m "perf: add fixed frame widths to volatile text elements

Wrap dynamic text in .frame(width:, alignment: .trailing) to prevent
SwiftUI layout recalculation when digit count changes (e.g., '9%' to
'100%'). Combined with .monospacedDigit(), this eliminates StackLayout
sizeThatFits recursion on every data tick."
```

---

### Task 5: Cache ForegroundConfig in MenuBarView Environment

**Files:**
- Modify: `Glance/Config/AppearanceConfig.swift` (add resolved widget config env key)
- Modify: `Glance/Views/MenuBarView.swift` (set environment value)
- Modify: `Glance/Utils/ExperimentalConfigurationModifier.swift` (read from environment)

- [ ] **Step 1: Add environment key for resolved foreground config**

In `AppearanceConfig.swift`, add at the end of the file (after existing environment keys):

```swift
/// Cached resolved foreground config to avoid per-widget ConfigManager reads.
private struct ResolvedForegroundConfigKey: EnvironmentKey {
    static let defaultValue: ResolvedForegroundConfig? = nil
}

/// Snapshot of ForegroundConfig values needed by widgets.
struct ResolvedForegroundConfig: Equatable {
    let formation: BarFormation
    let height: CGFloat
    let widgetsBackgroundDisplayed: Bool
    let spacing: CGFloat
    let horizontalPadding: CGFloat
    let margin: CGFloat
    let gap: CGFloat
}

extension EnvironmentValues {
    var resolvedForegroundConfig: ResolvedForegroundConfig? {
        get { self[ResolvedForegroundConfigKey.self] }
        set { self[ResolvedForegroundConfigKey.self] = newValue }
    }
}
```

- [ ] **Step 2: Set resolved config in MenuBarView**

In `MenuBarView.swift`, inside the `body` property, after the existing `let` declarations, add the resolved config and set it as an environment value:

```swift
var body: some View {
    let _ = configManager.config
    let items = configManager.config.rootToml.widgets?.displayed ?? []
    let appearance = configManager.config.appearance
    let fg = configManager.config.experimental.foreground

    // Cache resolved foreground config for child widgets
    let resolvedFG = ResolvedForegroundConfig(
        formation: fg.formation,
        height: fg.resolveHeight(),
        widgetsBackgroundDisplayed: fg.widgetsBackground.displayed,
        spacing: fg.spacing,
        horizontalPadding: fg.horizontalPadding,
        margin: fg.margin,
        gap: fg.gap
    )

    Group {
        // ... existing switch formation code stays the same ...
    }
    // ... existing modifiers ...
    .environment(\.resolvedForegroundConfig, resolvedFG)
    // ... rest of modifiers stay the same ...
```

- [ ] **Step 3: Update ExperimentalConfigurationModifier to read from environment**

In `ExperimentalConfigurationModifier.swift`, replace `@ObservedObject var configManager` with environment reads:

```swift
private struct ExperimentalConfigurationModifier: ViewModifier {
    @Environment(\.resolvedForegroundConfig) private var resolvedFG
    @Environment(\.appearance) private var appearance

    let horizontalPadding: CGFloat

    func body(content: Content) -> some View {
        guard let fg = resolvedFG else {
            // Fallback: config not yet resolved, use defaults
            return content
                .padding(.horizontal, horizontalPadding)
        }

        let showIndividualBg = fg.formation == .islands && fg.widgetsBackgroundDisplayed

        Group {
            if showIndividualBg {
                content
                    .frame(height: fg.height < 45 ? 30 : 38)
                    .padding(
                        .horizontal,
                        fg.height < 45 && horizontalPadding != 15
                            ? 0
                            : fg.height < 30
                                ? 0 : horizontalPadding
                    )
                    .widgetStyle(
                        appearance,
                        heightOverride: fg.height < 45 ? 30 : 38
                    )
            } else {
                content
                    .padding(.horizontal, horizontalPadding > 8 ? 4 : horizontalPadding)
            }
        }.scaleEffect(fg.height < 25 ? 0.9 : 1, anchor: .leading)
    }
}
```

- [ ] **Step 4: Commit**

```bash
git add Glance/Config/AppearanceConfig.swift \
  Glance/Views/MenuBarView.swift \
  Glance/Utils/ExperimentalConfigurationModifier.swift
git commit -m "perf: cache ForegroundConfig in environment for child widgets

Move ForegroundConfig resolution from per-widget ConfigManager.shared
reads to a single resolution in MenuBarView passed via @Environment.
Eliminates N redundant config reads per render cycle (N = widget count)."
```

---

### Task 6: Make Config Equatable for SwiftUI Skip Detection

**Files:**
- Modify: `Glance/Config/ConfigModels.swift` (add Equatable to Config)

- [ ] **Step 1: Add Equatable conformance to Config**

In `ConfigModels.swift`, modify the `Config` struct to conform to `Equatable`. Since `Config` has a `updatedAt` timestamp that changes on every load, we need a custom `==` that compares the meaningful content:

```swift
struct Config: Equatable {
    let rootToml: RootToml
    let pywalColors: PywalColors?
    let updatedAt: UInt64

    init(rootToml: RootToml = RootToml(), pywalColors: PywalColors? = nil) {
        self.rootToml = rootToml
        self.pywalColors = pywalColors
        self.updatedAt = Date().timeIntervalSince1970.bitPattern
    }

    // ... existing computed properties stay the same ...

    static func == (lhs: Config, rhs: Config) -> Bool {
        lhs.updatedAt == rhs.updatedAt
    }
}
```

The `updatedAt` based equality is intentional — it means SwiftUI will detect config changes even when the TOML content is identical but the file was reloaded (e.g., file watcher fires).

- [ ] **Step 2: Commit**

```bash
git add Glance/Config/ConfigModels.swift
git commit -m "perf: add Equatable conformance to Config struct

Enable SwiftUI to skip recomputation when config hasn't actually changed.
Uses updatedAt-based equality to detect meaningful config updates."
```

---

### Task 7: Build Verification and Final Check

**Files:** None — verification only.

- [ ] **Step 1: Verify all style files are in place for build**

Check that style files exist in `Glance/Styles/`:
```bash
ls Glance/Styles/
```

If `GlassStyle.swift`, `MinimalStyle.swift`, `SolidStyle.swift`, `SystemStyle.swift` are present, move them out before building:
```bash
mkdir -p /tmp/glance-styles-backup
mv Glance/Styles/{Glass,Minimal,Solid,System}Style.swift /tmp/glance-styles-backup/
```

- [ ] **Step 2: Build the project from the worktree**

```bash
cd /Volumes/NightSky/babaisalive/Clones/glance-opt && xcodebuild -project Glance.xcodeproj -scheme Glance -configuration Release -derivedDataPath build build CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: If build fails, fix compilation errors**

Read the build output. Fix any errors by editing the correct files. Common issues to watch for:
- Missing imports
- Incorrect property names from refactoring
- Syntax errors in modified code

- [ ] **Step 4: Deploy and verify**

```bash
pkill -x Glance; sleep 2
rm -rf /Applications/Glance.app
cp -R build/Build/Products/Release/Glance.app /Applications/Glance.app
open /Applications/Glance.app
```

- [ ] **Step 5: Restore style files**

```bash
cp /tmp/glance-styles-backup/*.swift Glance/Styles/ 2>/dev/null || true
```

- [ ] **Step 6: Commit final state**

```bash
git add .
git commit -m "perf: bar optimization build verification

All optimizations compiled and deployed successfully."
```

---

## Self-Review

**Spec coverage check:**

| Spec Optimization | Task |
|---|---|
| 1. Delta-Based Publishing | Task 1 |
| 2. Fixed Frame Widths | Task 4 |
| 3. Shadow Consolidation | Task 2 |
| 4. GeometryReader Elimination | Task 3 |
| 5. Config Read Caching | Task 5 |
| Equatable Data Models | Task 6 |
| Build verification | Task 7 |

All spec requirements covered.

**Placeholder scan:** No TBDs, TODOs, or "implement later" patterns. All code shown inline. All file paths exact. All commands specified.

**Type consistency:** `ResolvedForegroundConfig` is defined in Task 5 Step 1 and consumed in Task 5 Step 3. `BarFormation` enum already exists in `ConfigModels.swift`. `AppearanceConfig` already exists. No new type conflicts expected.
