# Glance — Custom macOS Status Bar

Modern macOS status bar replacement with liquid glass UI, native Spaces support, and custom widgets. Originally forked from Barik, now a standalone project.

**Version:** 1.1.2
**Author:** azixxxxx (Azim Sukhanov)
**GitHub:** https://github.com/azixxxxx/glance

## System Context

- **Hardware:** Mac Mini M4, 1080p display
- **Network:** Wi-Fi only (no Ethernet)
- **Window Manager:** Native macOS (no yabai, no AeroSpace)
- **macOS:** Sequoia
- **Theme:** Tokyo Night (dark)
- **Config file:** `~/.glance-config.toml`
- **Deployed at:** `/Applications/Glance.app`
- **Bundle ID:** `com.azimsukhanov.glance`

## Build & Deploy

```bash
# Build (from project root)
xcodebuild -project Glance.xcodeproj -scheme Glance -configuration Release \
  -derivedDataPath build build \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# Deploy (MUST kill, rm -rf, then copy — cp alone won't overwrite a running app)
pkill -x Glance; sleep 2
rm -rf /Applications/Glance.app
cp -R build/Build/Products/Release/Glance.app /Applications/Glance.app
open /Applications/Glance.app

# Build DMG + ZIP for distribution
./scripts/build-dmg.sh
# Output: release/Glance-X.Y.Z.dmg + release/Glance-X.Y.Z.zip
```

**Important:** Always `rm -rf` before `cp -R`. Otherwise the old binary may persist even after rebuilding.

## Project Structure

```
Glance/
├── Info.plist                          # LSUIElement=true, Sparkle keys, Location keys
├── AppDelegate.swift                   # App lifecycle, tray icon, login item, Sparkle updater
├── GlanceApp.swift                     # SwiftUI app entry (@main)
├── Constants.swift                     # App constants
├── Config/
│   ├── ConfigManager.swift             # Config loading, file watching, live reload
│   ├── ConfigModels.swift              # RootToml, Config, style support
│   ├── AppearanceConfig.swift          # Visual params struct + resolvedCornerRadius
│   └── PresetRegistry.swift            # 11 built-in presets (Preset enum)
├── MenuBarPopup/                       # Popup infrastructure (glass background)
├── Resources/                          # Asset catalog (colors, icons)
├── Settings/
│   ├── SettingsWindowController.swift  # NSWindow manager for Settings
│   ├── SettingsView.swift              # Tab-based settings (sidebar nav)
│   └── Tabs/
│       ├── GeneralSettingsTab.swift    # Preset picker, appearance sliders
│       ├── WidgetsSettingsTab.swift    # Widget list config
│       ├── SpacesSettingsTab.swift     # Spaces widget config
│       ├── TimeSettingsTab.swift       # Time format config
│       └── AboutSettingsTab.swift      # Version, credits (Made by azixxxxx)
├── Styles/
│   ├── BarStyleProvider.swift          # Protocol + BarStyle enum + @Environment keys
│   ├── GlassStyle.swift                # Liquid glass — blur + highlight + border
│   ├── SolidStyle.swift                # Flat opaque background
│   ├── MinimalStyle.swift              # Transparent, text/icons only
│   └── SystemStyle.swift               # Native macOS .regularMaterial
├── Utils/
│   ├── ExperimentalConfigurationModifier.swift  # Widget backgrounds (reads appearance)
│   ├── ImageCache.swift                # Async image caching
│   ├── VersionChecker.swift            # Version tracking for "What's New"
│   └── WindowGapManager.swift          # AX-based window gap enforcement
├── Views/
│   ├── MenuBarView.swift               # Widget registry — routes widget IDs to views
│   ├── BackgroundView.swift            # Bar background
│   ├── OnboardingView.swift            # First-launch welcome (4 pages)
│   ├── OnboardingWindowController.swift # Onboarding window lifecycle
│   └── AppUpdater.swift                # Auto-update from GitHub releases
└── Widgets/
    ├── ActiveApp/
    │   ├── ActiveAppViewModel.swift    # NSWorkspace frontmost app tracking
    │   └── ActiveAppWidget.swift
    ├── Battery/
    │   ├── BatteryManager.swift        # IOKit health, cycles, temp, time remaining
    │   ├── BatteryWidget.swift
    │   └── BatteryPopup.swift          # Ring + health/cycles/temp/power details
    ├── Network/
    │   ├── NetworkWidget.swift         # Wi-Fi + Ethernet icons
    │   ├── NetworkViewModel.swift      # getifaddrs speed, CoreWLAN info, local IP
    │   └── NetworkPopup.swift          # Signal bars, live speed, IP, Tx Rate
    ├── NowPlaying/
    │   ├── NowPlayingManager.swift     # AppleScript bridge (Music + Spotify), album field
    │   ├── NowPlayingWidget.swift
    │   └── NowPlayingPopup.swift       # Album art, progress bar, playback controls
    ├── Spaces/
    │   ├── SpacesModels.swift          # Protocols + type erasure
    │   ├── SpacesViewModel.swift       # Provider selection + IconCache
    │   ├── SpacesWidget.swift
    │   ├── Native/
    │   │   ├── NativeSpacesModels.swift
    │   │   └── NativeSpacesProvider.swift  # CGS private API
    │   ├── Aerospace/
    │   └── Yabai/
    ├── Script/
    │   ├── ScriptViewModel.swift       # Shell command execution at interval
    │   └── ScriptWidget.swift          # Display script output as text
    ├── SystemBanner/                   # System banner + changelog
    ├── SystemMonitor/
    │   ├── SystemMonitorViewModel.swift # CPU (host_statistics) + RAM (vm_statistics64)
    │   ├── SystemMonitorWidget.swift    # CPU% + RAM usage in bar
    │   └── SystemMonitorPopup.swift     # Usage bars + memory details
    ├── Time+Calendar/
    │   ├── TimeWidget.swift
    │   ├── CalendarManager.swift
    │   └── CalendarPopup.swift         # Calendar grid + events, luminance-based contrast
    ├── Volume/
    │   ├── VolumeWidget.swift          # Icon + scroll overlay
    │   ├── VolumeViewModel.swift       # CoreAudio volume + output device name
    │   └── VolumePopup.swift           # Slider + mute + output device info
    └── Weather/
        ├── WeatherViewModel.swift      # OpenMeteo API + CoreLocation
        ├── WeatherWidget.swift         # Temp + weather icon in bar
        └── WeatherPopup.swift          # Current conditions + 5-day forecast
```

## Preset System

11 built-in presets in `PresetRegistry.swift`. Each preset defines a full `AppearanceConfig`.

| Preset | Rendering | Description |
|---|---|---|
| `liquid-glass` | glass | Default — blur, bright gradient border, capsule |
| `frosted` | glass | Softer blur, dim border, rounded rect |
| `flat-dark` | solid | 2D, no blur, thin border |
| `minimal` | minimal | Text/icons only, no background |
| `neon` | solid | Bright pink glowing border |
| `tokyo-night` | solid | Tokyo Night color scheme |
| `dracula` | solid | Dracula color scheme |
| `gruvbox` | solid | Gruvbox color scheme |
| `nord` | solid | Nord color scheme |
| `catppuccin` | solid | Catppuccin Mocha color scheme |
| `solarized` | solid | Solarized Dark color scheme |

### Appearance Resolution

```
Config preset → Preset.defaults (AppearanceConfig)
  → .applying(overrides: rootToml.appearanceOverrides)
    → Final AppearanceConfig
      → .environment(\.appearance, ...) in MenuBarView
        → Widgets/popups read @Environment(\.appearance)
```

`AppearanceConfig` fields: renderingStyle, roundness (0-50), borderWidth, borderTopOpacity, borderMidOpacity, borderBottomOpacity, fillOpacity, glowOpacity, glowRadius, shadowOpacity, shadowRadius, shadowY, blurMaterial, popupDarkTint, popupRoundness, foregroundColor, accentColor, borderColor, borderColor2, widgetBackgroundColor, glowColor.

### Legacy Support

`style = "glass"` → maps to `liquid-glass` preset via `Preset.fromLegacyStyle()`.

## Style System

All widget backgrounds and popup backgrounds go through `BarStyleProvider`.

### Rendering Styles (BarStyle enum)

| Style | Description |
|---|---|
| `glass` | ultraThinMaterial + highlight gradient + gradient border + shadow |
| `solid` | Flat opaque fill, no blur |
| `minimal` | No background at all |
| `system` | Native macOS `.regularMaterial` |

### Glass Layers (GlassStyle)

Widget capsules:
1. `.ultraThinMaterial` — base blur
2. Linear gradient overlay (highlight) — configurable opacity
3. Linear gradient overlay (inner shadow) — configurable opacity
4. Gradient stroke (border) — configurable width, top/mid/bottom opacity
5. Drop shadow — configurable opacity, radius, y-offset
6. Outer glow — configurable opacity, radius, color

Popups add a dark tint between blur and highlight for text readability.

## Widgets

### Volume Widget (`Widgets/Volume/`)
- **Widget ID:** `default.volume`
- Speaker icon (SF Symbol) reflecting current volume level
- Scroll wheel adjusts volume (NSView overlay for scroll event capture)
- Click opens popup with slider + mute toggle + output device info
- CoreAudio `AudioToolbox` API for volume get/set/mute
- Output device name via `AudioObjectGetPropertyData` + `Unmanaged<CFString>`
- **Event-driven** via `AudioObjectAddPropertyListener` — zero polling, updates only on volume/mute/device changes

### Network Widget (`Widgets/Network/`)
- **Widget ID:** `default.network`
- Wi-Fi + Ethernet status icons with color states
- Popup: signal bars, RSSI, quality, band badge, live upload/download speed, local IP, channel, Tx Rate, noise
- Speed tracking via `getifaddrs` + `if_data` byte counters (3s interval)
- Local IP via `getifaddrs` scanning `en0`/`en1` for `AF_INET`
- Tx Rate via CoreWLAN `transmitRate()`

### Battery Widget (`Widgets/Battery/`)
- **Widget ID:** `default.battery`
- Battery level with charging indicator
- Popup: ring progress + health %, cycle count, temperature, power source, time remaining
- IOKit `AppleSmartBattery` via `IORegistryEntryCreateCFProperties`
- Temperature from `dict["Temperature"]` / 100 (centi-degrees)
- Time remaining via `IOPSGetTimeRemainingEstimate()`

### Now Playing Widget (`Widgets/NowPlaying/`)
- **Widget ID:** `default.nowplaying`
- Current track with album art thumbnail
- Popup: large album art (220x220), title/artist/album, smooth progress bar with knob + glow, playback controls
- AppleScript bridge for Music + Spotify (7 pipe-separated fields: state|title|artist|album|artworkURL|position|duration)
- **Adaptive polling:** 3s when playing, 5s when paused, 5s when no music app running. Skips AppleScript entirely if no music app is running. Compiled AppleScript caching eliminates repeated script compilation
- **Resilience:** `NowPlayingManager` uses a grace period — 10 consecutive nil responses before clearing `nowPlaying`. Prevents widget from disappearing due to transient AppleScript failures (Mac sleep, Spotify restart, temporary Automation permission issues)

### Active App Widget (`Widgets/ActiveApp/`)
- **Widget ID:** `default.activeapp`
- Frontmost app name with animated transitions
- `NSWorkspace.didActivateApplicationNotification`

### Time Widget (`Widgets/Time+Calendar/`)
- **Widget ID:** `default.time`
- ICU date format patterns via `formatter.dateFormat`
- Calendar popup: month grid, weekday headers, today highlight with luminance-based contrast
- Events list (today + tomorrow) via EventKit

### Spaces Widget (`Widgets/Spaces/`)
- **Widget ID:** `default.spaces`
- Native macOS spaces (CGS private API), yabai, or AeroSpace
- App icons per space, click to switch

### Weather Widget (`Widgets/Weather/`)
- **Widget ID:** `default.weather`
- Temperature + weather condition icon (SF Symbols) in bar
- Click opens popup: current conditions (temp, feels like, humidity, wind), location name, 5-day forecast
- OpenMeteo API (free, no API key required)
- CoreLocation for automatic coordinates, reverse geocoding for city name
- Auto-refreshes every 10 minutes
- WMO weather codes mapped to SF Symbols and descriptions

### System Monitor Widget (`Widgets/SystemMonitor/`)
- **Widget ID:** `default.systemmonitor`
- CPU usage % and RAM usage (GB) in bar
- Click opens popup: CPU/RAM usage bars with color thresholds, memory details (used/total/pressure)
- CPU via `host_statistics` (HOST_CPU_LOAD_INFO) — delta between ticks
- Memory via `host_statistics64` (VM_INFO64) — active + wired + compressed
- Polls every 3 seconds
- Color thresholds: green < 50/70%, yellow < 80/85%, red above

### Script Widget (`Widgets/Script/`)
- **Widget ID:** `script.<name>` (e.g. `script.vpn-status`)
- Runs arbitrary shell command at configurable interval
- Displays stdout as text in bar (trimmed, single line)
- Config: `command` (string, required), `interval` (int seconds, default 10)
- Executes via `/bin/sh -c`, inherits environment
- Example config:
  ```toml
  [widgets.script.vpn-status]
  command = "scutil --ncs | grep -q Connected && echo '🟢 VPN' || echo '🔴 VPN'"
  interval = 10
  ```

## App Features

### Tray Icon (AppDelegate)
- `NSStatusItem` with SF Symbol `eye` (template image)
- Menu: Settings... (Cmd+,), Check for Updates... (Sparkle), Launch at Login toggle, Quit (Cmd+Q)
- Login item via `SMAppService.mainApp` (macOS 13+)
- `SPUStandardUpdaterController` for Sparkle auto-updates

### Onboarding
- `OnboardingWindowController` shows on first launch
- 4 pages: Welcome, Widgets, Presets, Config
- `UserDefaults` key: `hasSeenOnboarding`
- Uses `NSApp.applicationIconImage` (NOT `NSImage(named: "AppIcon")` — that doesn't work for AppIcon assets)

### Settings GUI
- `SettingsWindowController` — singleton, NSWindow managed manually (LSUIElement app)
- Tabs: General (preset picker, appearance), Widgets, Spaces, Time, About
- About tab: version, "Made by azixxxxx", GitHub link

### What's New / Changelog System
- `VersionChecker` tracks installed version in `~/Library/Application Support/glance/current_glance_version`
- On launch, `AppDelegate` compares current vs saved version. If different → posts `ShowWhatsNewBanner` notification
- `SystemBannerWidget` shows green "What's New" button in bar → opens `ChangelogPopup`
- `ChangelogPopup` fetches `CHANGELOG.md` from `https://raw.githubusercontent.com/azixxxxx/glance/main/CHANGELOG.md`
- Extracts section for current version (matches `## X.Y.Z` header), displays as Markdown
- **Important:** When releasing a new version, ALWAYS update `CHANGELOG.md` with the new version's entry BEFORE creating the release. Otherwise the popup shows "Changelog for vX.Y.Z not found"

### Dual Update System
- **Sparkle** (primary): Checks `appcast.xml` on GitHub for EdDSA-signed updates. Handles download + install via native macOS update flow. Triggered by "Check for Updates..." menu item and automatic checks on launch
- **AppUpdater** (fallback): Polls GitHub API (`/repos/azixxxxx/glance/releases/latest`) every 30 minutes. Shows "Update" button in bar if newer version exists. Downloads ZIP, unzips, replaces `/Applications/Glance.app` via shell script
- Both systems coexist — Sparkle is preferred for signed updates, AppUpdater catches cases where Sparkle fails

### Distribution
- `scripts/build-dmg.sh` — builds Release, creates DMG + ZIP in `release/`
- DMG includes Applications symlink for drag-and-drop install

## Known Technical Details

### CGS Private APIs (NativeSpacesProvider)

```swift
@_silgen_name("CGSMainConnectionID")
private func CGSMainConnectionID() -> Int

@_silgen_name("CGSCopyManagedDisplaySpaces")
private func CGSCopyManagedDisplaySpaces(_ conn: Int) -> CFArray

@_silgen_name("CGSCopySpacesForWindows")
private func CGSCopySpacesForWindows(_ conn: Int, _ mask: Int, _ windowIDs: CFArray) -> CFArray?
```

**What does NOT work on macOS Sequoia:**
- `CGSManagedDisplaySetCurrentSpace` — pulls windows to current space instead of switching
- `CGSShowSpaces` / `CGSHideSpaces` — same problem

**What works:** App activation approach — find a window exclusively on the target space, activate its `NSRunningApplication`. macOS switches spaces automatically.

### Thread Safety (NativeSpacesProvider)

`SpacesViewModel` polls every 1s on `DispatchQueue.global(.userInitiated)` with additional event-driven refresh via `NSWorkspace` notifications (app activate/launch/terminate). `NativeSpacesProvider.getSpacesWithWindows()` uses `NSLock` to serialize access to `windowCache` dictionary (Swift Dictionary is not thread-safe). Regular app names are cached and refreshed only on app launch/terminate events.

### Race Condition During Space Transitions

CGS reports the new space as "Current Space" before `CGWindowListCopyWindowInfo(.optionOnScreenOnly)` updates. Solution: verify the first on-screen window belongs to the current space via `CGSCopySpacesForWindows` before caching.

### NSImage(named: "AppIcon") Does NOT Work

macOS does not expose the AppIcon asset catalog image via `NSImage(named:)`. Use `NSApp.applicationIconImage` instead for displaying the app icon at runtime.

### CoreAudio CFString Pattern

Reading audio device name requires `Unmanaged<CFString>` pattern to avoid unsafe pointer warnings:
```swift
var name: Unmanaged<CFString>?
withUnsafeMutablePointer(to: &name) { ptr in
    AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, ptr)
}
if let cfName = name?.takeUnretainedValue() { ... }
```

### CLAuthorizationStatus on macOS

On macOS, `CLAuthorizationStatus` uses `.authorized` (not `.authorizedWhenInUse` which is iOS-only). `requestWhenInUseAuthorization()` doesn't exist on macOS — `startUpdatingLocation()` triggers the system permission prompt automatically. The Weather widget handles this with an IP geolocation fallback via `ipapi.co/json/` when Location is denied.

### Xcode Auto-Discovery of Swift Files

Xcode with `PBXFileSystemSynchronizedRootGroup` (used in this project) automatically compiles ALL `.swift` files in the `Glance/` directory tree. Files that aren't in `project.pbxproj` explicitly are still compiled. This means unfinished/WIP `.swift` files will cause build errors. **Workaround:** move them out of the directory before building (see Release Process step 2).

### AppleScript Transient Failures

AppleScript calls to Spotify/Music can return nil temporarily after Mac sleep/wake, app restart, or Automation permission re-prompts. The `NowPlayingManager` handles this with a grace period (`consecutiveNilCount` / `nilThreshold = 10`). Only after 10 consecutive nil responses (~3 seconds) does it clear `nowPlaying`. This prevents the widget from flickering or disappearing during brief interruptions. TCC permissions can be checked at `~/Library/Application Support/com.apple.TCC/TCC.db` — `auth_value=2` means granted for `kTCCServiceAppleEvents`.

### Calendar Today Contrast

`CalendarDaysView.todayTextColor` calculates luminance of `accentColor` (0.299R + 0.587G + 0.114B) and returns `.black` if light (>0.6) or `.white` if dark. This ensures the today circle text is always readable regardless of preset.

## Configuration Reference

Config file location: `~/.glance-config.toml`

```toml
theme = "dark"
preset = "liquid-glass"   # See Preset System above

# Override individual appearance values:
# [appearance]
# roundness = 50
# border-width = 1.0
# foreground-color = "#ffffff"
# accent-color = "#7aa2f7"

[widgets]
displayed = [
    "default.spaces",
    "divider",
    "default.activeapp",
    "default.nowplaying",
    "spacer",
    "default.weather",
    "default.systemmonitor",
    "default.volume",
    "default.network",
    "divider",
    "default.time",
]

# Script widgets (user-defined shell commands):
# "script.my-widget"  — any name after "script."

[widgets.default.spaces]
space.show-key = true
window.show-title = true
window.title.max-length = 50

[widgets.default.battery]
show-percentage = true
warning-level = 30
critical-level = 10

[widgets.default.time]
format = "E d MMM, H:mm"
calendar.format = "H:mm"
calendar.show-events = true

[popup.default.time]
view-variant = "box"

# Script widget example:
# [widgets.script.vpn-status]
# command = "scutil --ncs | grep -q Connected && echo '🟢' || echo '🔴'"
# interval = 10

[background]
enabled = true

[experimental.foreground]
height = "default"
horizontal-padding = 20
spacing = 12

[experimental.foreground.widgets-background]
displayed = true
blur = 5

[experimental.background]
displayed = true
height = "default"
blur = 4
```

## Release Status

- **v1.1.2 released** on 2026-03-10
- **v1.1.1 released** on 2026-03-09
- **v1.1.0 released** on 2026-03-08
- **v1.0.0 released** on 2026-03-06
- **GitHub:** https://github.com/azixxxxx/glance
- **Latest Release:** https://github.com/azixxxxx/glance/releases/tag/v1.1.2
- **Homebrew:** `brew tap azixxxxx/tap && brew install --cask glance`
- **Posted:** r/unixporn, r/opensource
- **Pending:** r/macapps (need 10 comment karma in their subreddit first), r/mac
- **Future:** Product Hunt, Hacker News

## Window Gap Manager (`Utils/WindowGapManager.swift`)

- Uses Accessibility API to monitor all app windows via `AXObserver`
- Listens for `kAXWindowResizedNotification`, `kAXWindowMovedNotification`, `kAXWindowCreatedNotification`, `kAXFocusedWindowChangedNotification`
- Pushes windows below `barHeight + 6px` gap if they overlap the bar
- Skips full-screen windows (`AXFullScreen` attribute) and Glance's own PID
- Requires Accessibility permission; prompts on first launch, polls until granted
- **Initial scan on startup:** After registering AX observers, scans all existing windows of each app via `kAXWindowsAttribute` and adjusts overlapping ones. Without this, windows restored from previous session (e.g. after reboot) stay behind the bar because no AX event fires for them.
- **Delayed sweep (2s):** A second pass runs 2 seconds after startup to catch windows that macOS state restoration repositioned after the initial scan.
- **Important:** macOS may revoke Accessibility after app rebuild (new binary hash). User needs to re-enable and restart the app.

## Release Process

When making a new release, follow ALL steps. This is the complete procedure.

### 1. Bump version

Update version in TWO places (both required — Xcode uses `MARKETING_VERSION`, not Info.plist):

- `Glance/Info.plist` → `CFBundleShortVersionString` and `CFBundleVersion`
- `Glance.xcodeproj/project.pbxproj` → `MARKETING_VERSION` (replace_all, appears in Debug + Release configs) and `CURRENT_PROJECT_VERSION`

### 2. Update CHANGELOG.md

Add a new `## X.Y.Z` section at the top of `CHANGELOG.md` with the changes for this release. This is required for the "What's New" popup to show content after users update.

### 3. Move unfinished Style files before build

Xcode auto-discovers `.swift` files. Unfinished Style files in `Glance/Styles/` (GlassStyle.swift, MinimalStyle.swift, SolidStyle.swift, SystemStyle.swift) will cause build errors. Move them before building:

```bash
mkdir -p /tmp/glance-styles-backup
mv Glance/Styles/GlassStyle.swift Glance/Styles/MinimalStyle.swift \
   Glance/Styles/SolidStyle.swift Glance/Styles/SystemStyle.swift \
   /tmp/glance-styles-backup/
```

Restore after build:
```bash
cp /tmp/glance-styles-backup/*.swift Glance/Styles/
```

### 4. Build DMG + ZIP

```bash
./scripts/build-dmg.sh
# Output: release/Glance-X.Y.Z.dmg + release/Glance-X.Y.Z.zip
```

Verify the version in the output matches what you set in step 1.

### 5. Sign ZIP for Sparkle

```bash
./build/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update release/Glance-X.Y.Z.zip
```

**Note:** This triggers a macOS Keychain access popup. The user MUST approve it in the GUI. It will NOT work in a headless/CLI-only environment. The output looks like:

```
sparkle:edSignature="<base64>" length="<bytes>"
```

Save this output for step 5.

**If the tool hangs:** it's waiting for Keychain approval. Tell the user to approve it.

### 6. Update appcast.xml

Add a new `<item>` inside `<channel>` with the signature from step 4:

```xml
<item>
    <title>Version X.Y.Z</title>
    <sparkle:version>BUILD_NUMBER</sparkle:version>
    <sparkle:shortVersionString>X.Y.Z</sparkle:shortVersionString>
    <pubDate>DATE_RFC2822</pubDate>
    <enclosure
        url="https://github.com/azixxxxx/glance/releases/download/vX.Y.Z/Glance-X.Y.Z.zip"
        type="application/octet-stream"
        sparkle:edSignature="SIGNATURE_FROM_STEP_4"
        length="FILE_SIZE_BYTES"
    />
</item>
```

Get the RFC 2822 date: `date -R`
Get file size: `stat -f%z release/Glance-X.Y.Z.zip` (macOS) or `wc -c < release/Glance-X.Y.Z.zip`

### 7. Commit and push

```bash
git add -A  # or specific files
git commit -m "chore: bump version to X.Y.Z"
git push origin main
```

### 8. Create GitHub Release

```bash
gh release create vX.Y.Z \
  release/Glance-X.Y.Z.dmg \
  release/Glance-X.Y.Z.zip \
  --repo azixxxxx/glance \
  --title "Glance vX.Y.Z" \
  --notes "Release notes here"
```

### 9. Update Homebrew cask

```bash
# Get SHA256 of the new ZIP
shasum -a 256 release/Glance-X.Y.Z.zip

# Clone and update the tap
gh repo clone azixxxxx/homebrew-tap /tmp/homebrew-tap
# Edit /tmp/homebrew-tap/Casks/glance.rb — update version and sha256
cd /tmp/homebrew-tap && git add -A && git commit -m "chore: bump Glance cask to vX.Y.Z" && git push origin main
```

### 10. Deploy locally

```bash
pkill -x Glance; sleep 2
rm -rf /Applications/Glance.app
cp -R build/Build/Products/Release/Glance.app /Applications/Glance.app
open /Applications/Glance.app
```

### 11. Update CLAUDE.md

Update the "Release Status" section with the new version and date.

## Sparkle Auto-Updates

- **Sparkle 2.9.0** integrated via SPM
- EdDSA signing key stored in macOS Keychain (generated via `generate_keys`)
- Public key in Info.plist: `SUPublicEDKey`
- Feed URL: `https://raw.githubusercontent.com/azixxxxx/glance/main/appcast.xml`
- `SUEnableAutomaticChecks = true` — checks on app launch
- "Check for Updates..." menu item in tray via `SPUStandardUpdaterController`
- `sign_update` tool at: `build/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update`
- `generate_keys` tool at: `build/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys`
- **Critical:** `appcast.xml` MUST contain `<item>` entries for Sparkle to find updates. An empty `<channel>` means Sparkle never detects any available version. Always add a new `<item>` during the release process (step 5)

## TODO / Roadmap

### Stability & Polish

- **CGS graceful degradation** — wrap all CGS calls in `NativeSpacesProvider.swift` in error handling so widget shows "Spaces unavailable" instead of crashing if Apple breaks the API. `CGWindowListCopyWindowInfo` (public API) is already safe
- **NowPlaying → MediaRemote.framework** — replace AppleScript bridge with private `MRMediaRemoteGetNowPlayingInfo` API. Benefits: instant (vs 100-500ms AppleScript), supports ALL media apps (Safari, Chrome, VLC, etc.), no Automation permission needed. Used by SketchyBar, Stats, and other bar utilities. Risk: private API, may break between macOS versions
- **Simplify update system** — currently two parallel mechanisms (Sparkle + AppUpdater). Consider removing AppUpdater and relying on Sparkle only, or making AppUpdater a fallback-only path
- ~~**SpacesViewModel polling tuning**~~ — DONE in v1.1.2: reduced to 1s + event-driven refresh

### UX Improvements

- **Keyboard shortcut show/hide bar** — global hotkey to toggle bar visibility (useful for fullscreen or presentations)
- **Drag & drop widget reordering** in Settings GUI — remove need to edit TOML manually for widget order
- **Auto-hide bar** when fullscreen apps are active — detect `NSApplication.presentationOptions` or fullscreen window state
- **Widget appear/disappear animations** — smooth transitions when NowPlaying or other conditional widgets show/hide (currently abrupt)

### New Widgets

- **Bluetooth** — connected devices list, AirPods battery level (IOBluetooth framework). Popup: device list with battery indicators
- **Brightness** — screen brightness icon + scroll-to-adjust (like Volume widget). CoreDisplay or IOKit for brightness control
- **Focus/DND** — indicator showing current Focus mode status. `NSDoNotDisturbEnabled` or `DNDDStatus` private framework
- **Pomodoro** — built-in timer with work/break intervals. Click to start/pause, popup for settings
- **Disk** — free space indicator for main volume. `FileManager.attributesOfFileSystem` or `statfs`
- **Clipboard** — clipboard history viewer. `NSPasteboard.general` monitoring with popup showing recent items
- **Shortcuts** — quick-launch buttons for Shortcuts.app automations or custom actions

### Ecosystem & Architecture

- **Plugin API / Widget SDK** — allow users to create custom widgets beyond Script. Options: SwiftUI-based plugin bundles, JSON-declarative widget definitions, or WebView-based widgets
- **Community presets / theme sharing** — export/import preset configs as files. GitHub repo with community-contributed themes. Potential CLI: `glance theme install <url>`
- **Multi-monitor support** — separate bar window per display, synchronized state. Requires significant refactoring of window management
- **Localization** — i18n system for UI strings (Russian, Chinese as first targets). Currently all strings are hardcoded

## Debugging Tips

- **NSLog/print don't work** from SwiftUI body. Use file-based logging:
  ```swift
  try? "message\n".write(toFile: "/tmp/glance_debug.log", atomically: true, encoding: .utf8)
  ```
- **Deployed app not updating?** Always `rm -rf /Applications/Glance.app` before `cp -R`.
- **Windows appearing on wrong space?** Check `CGSCopySpacesForWindows` verification in `getSpacesWithWindows()`.
- **BetterDisplay or virtual displays** can create extra entries in `CGSCopyManagedDisplaySpaces`. The code uses `displaySpaces.first` (main display only).
- **Crash on boot (data race)?** `NativeSpacesProvider` uses `NSLock` to prevent concurrent Dictionary mutation.
- **Icon not showing?** Use `NSApp.applicationIconImage`, not `NSImage(named: "AppIcon")`.
- **Onboarding not showing?** Check `defaults read com.azimsukhanov.glance hasSeenOnboarding`. Reset with `defaults delete`.
- **Weather widget not showing?** Check Info.plist has `NSLocationUsageDescription` and `NSLocationWhenInUseUsageDescription`. Without these, CoreLocation silently denies, coordinates are never fetched, and the widget renders nothing. If Location is denied, the IP fallback (`ipapi.co`) should kick in.
- **Build fails with BarStyleProvider errors?** Unfinished Style files (GlassStyle.swift, etc.) are being auto-discovered by Xcode. Move them out before building (see Release Process step 2).
- **`sign_update` hangs?** It's waiting for macOS Keychain access popup. User must approve in GUI. Won't work in headless environments.
- **Windows overlap bar after reboot?** WindowGapManager initial scan should handle this. If it doesn't, check that Accessibility permission is still granted (macOS revokes after binary hash change).
- **Sparkle "Check for Updates" shows error?** Verify `appcast.xml` is pushed to `main` branch and accessible at `https://raw.githubusercontent.com/azixxxxx/glance/main/appcast.xml`.
- **Version not bumped in build?** Xcode uses `MARKETING_VERSION` from `project.pbxproj`, not from `Info.plist`. Must update BOTH.
- **Now Playing widget disappeared?** Likely transient AppleScript failure. App restart usually restores it. The grace period (10 consecutive nil = ~3s) prevents most temporary disappearances. If persistent, check Automation permissions in System Settings > Privacy > Automation for Glance → Spotify/Music.
- **"What's New" popup is empty?** Check that `CHANGELOG.md` exists in the repo root AND has a `## X.Y.Z` section matching the current `CFBundleShortVersionString`. The popup fetches from `https://raw.githubusercontent.com/azixxxxx/glance/main/CHANGELOG.md`.
- **Sparkle finds no updates?** Verify `appcast.xml` has at least one `<item>` entry. An empty `<channel>` means Sparkle sees no versions available.
