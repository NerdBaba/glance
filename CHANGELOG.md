# Changelog

## 1.1.2

### Performance
- Reduced idle CPU usage from ~20% to under 1% (without music playing) and ~2.6% average (with Spotify)
- **Spaces widget**: polling reduced from 100ms to 1s with event-driven refresh on app switch/launch/terminate; cached app name lookups instead of rebuilding every poll
- **Now Playing widget**: adaptive polling (3s playing, 5s paused/idle) instead of constant 300ms; compiled AppleScript caching eliminates repeated script compilation; skips AppleScript entirely when no music app is running
- **Volume widget**: replaced 500ms polling timer with zero-cost CoreAudio property listeners (event-driven)
- **Battery widget**: polling reduced from 1s to 30s; removed redundant recursive scheduling
- **Calendar**: polling reduced from 5s to 60s
- **Network**: WiFi info polling reduced from 5s to 10s; speed monitoring from 2s to 3s
- **System Monitor**: polling reduced from 2s to 3s
- **Menu bar panel**: constrained from full-screen to bar-height only, reducing SwiftUI layout area by ~20x
- All view models now diff-check data before publishing to avoid unnecessary SwiftUI re-renders

## 1.1.1

### Fixes
- Fixed Now Playing widget disappearing from the bar after temporary AppleScript failures (e.g. after Mac sleep or Spotify restart)
- Fixed "What's New" popup showing empty content after updates

## 1.1.0

### New Widgets
- **Weather** — current temperature, conditions, and 5-day forecast via OpenMeteo API with automatic location detection
- **System Monitor** — live CPU and RAM usage with color-coded thresholds
- **Script** — run any shell command and display its output in the bar

### New Features
- Sparkle auto-updates — the app now checks for updates automatically and shows an "Update" button in the bar
- Homebrew Cask support — `brew install --cask glance` via `azixxxxx/tap`
- "What's New" banner after updates with changelog popup

## 1.0.0

### Initial Release
- Custom macOS status bar replacement with liquid glass UI
- Native Spaces support with app icons per space (CGS private API)
- Now Playing widget with album art, progress bar, and playback controls (Spotify & Apple Music)
- Network widget with Wi-Fi signal, speed, and connection details
- Battery widget with health, cycle count, and temperature
- Volume widget with scroll-to-adjust and output device info
- Active App widget showing frontmost application
- Time & Calendar widget with month grid and events
- 11 built-in presets (Liquid Glass, Frosted, Tokyo Night, Dracula, and more)
- Live config reload from `~/.glance-config.toml`
- Window gap management via Accessibility API
- Onboarding flow for first launch
