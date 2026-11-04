import AppKit
import AudioToolbox
import OpenDirectory
import SwiftUI

/// Polybar formats backed by native macOS data. These are ordinary configurable
/// modules: labels, per-component colors, ramps, bars, fonts and actions are all
/// read from the same widget config as a custom/script module.
struct PolybarNativeWidget: View {
    let config: ConfigData
    @ObservedObject var configManager: ConfigManager
    @Environment(\.isBarPreviewRendering) private var preview
    private static let formatters = DateFormattingCache()
    private var formatters: DateFormattingCache { Self.formatters }

    @ViewBuilder var body: some View {
        switch config["native-source"]?.stringValue ?? "text" {
        case "user": GlanceUserBadge(config: config)
        case "weather": GlanceFormattedWeather(config: config, manager: configManager)
        case "visualizer": GlanceBarVisualizer(config: config, manager: configManager)
        case "cpu", "memory": PolybarSystemContent(config: config, manager: configManager)
        case "disk": PolybarDiskContent(config: config, manager: configManager)
        case "microphone": GlanceFormattedInputGain(config: config, manager: configManager)
        case "updates": GlanceFormattedUpdateCount(config: config, manager: configManager, preview: preview)
        case "volume": PolybarVolumeContent(config: config, manager: configManager, preview: preview)
        case "brightness": PolybarBrightnessContent(config: config, manager: configManager, preview: preview)
        case "bluetooth": GlanceFormattedBluetooth(config: config, manager: configManager)
        case "network": PolybarNetworkContent(config: config, manager: configManager)
        case "music": PolybarMusicContent(config: config, manager: configManager)
        case "music-artwork": GlanceMusicArtwork(config: config)
        case "battery": GlanceFormattedBattery(config: config, manager: configManager)
        case "temperature":
            if preview {
                PolybarFormattedContent(config: config, manager: configManager, value: 48, tokens: ["temperature-c": "48", "temperature-f": "118"])
            } else {
                PolybarTemperatureContent(config: config, manager: configManager)
            }
        case "keyboard": PolybarKeyboardContent(config: config, manager: configManager)
        case "workspaces", "window": PolybarSpacesContent(config: config, manager: configManager)
        case "date":
            TimelineView(.periodic(from: .now, by: config["seconds"]?.boolValue == true ? 1 : 60)) { context in
                let date = formatters.string(pattern: config["date-pattern"]?.stringValue ?? "EEE MMM d", date: context.date, timeZone: config["time-zone"]?.stringValue ?? "")
                let time = formatters.string(pattern: config["time-pattern"]?.stringValue ?? "HH:mm", date: context.date, timeZone: config["time-zone"]?.stringValue ?? "")
                if config["date-layout"]?.stringValue == "rail" {
                    railClock(date: date, time: time)
                } else if config["date-layout"]?.stringValue == "stacked" {
                    VStack(alignment: .leading, spacing: config["date-stack-spacing"]?.doubleValue ?? 0) {
                        PolybarFormattedContent(config: dateLineConfig(date: false), manager: configManager, tokens: ["date": date, "time": time])
                        PolybarFormattedContent(config: dateLineConfig(date: true), manager: configManager, tokens: ["date": date, "time": time])
                    }
                } else {
                    PolybarFormattedContent(config: config, manager: configManager, tokens: ["date": date, "time": time])
                }
            }
        default:
            if GlanceTransitionWidget.isDecoration(config),
               let shape = config["native-transition-shape"]?.stringValue, shape != "original" {
                GlanceTransitionWidget(config: config, manager: configManager)
            } else {
                PolybarFormattedContent(config: config, manager: configManager)
            }
        }
    }

    private func railClock(date: String, time: String) -> some View {
        let sample = ProcessInfo.processInfo.environment
        let dateParts = (preview ? sample["GLANCE_PREVIEW_TOKEN_DATE"] ?? date : date).components(separatedBy: "\n")
        let timeParts = (preview ? sample["GLANCE_PREVIEW_TOKEN_TIME"] ?? time : time).components(separatedBy: "\n")
        let rows = [dateParts.first ?? "", dateParts.dropFirst().first ?? "", timeParts.first ?? "", timeParts.dropFirst().first ?? "", timeParts.dropFirst(2).first ?? ""]
        return VStack(spacing: config["rail-clock-spacing"]?.doubleValue ?? 3) {
            railClockRow(rows[0], fontKey: "rail-weekday-font", fallback: "HelveticaNeue:size=12", height: 14)
            railClockRow(rows[1], fontKey: "rail-date-font", fallback: "HelveticaNeue:size=14", height: 20)
            Rectangle().fill(Color.secondary.opacity(0.3)).frame(width: 16, height: 1)
            railClockRow(rows[2], fontKey: "rail-time-font", fallback: "HelveticaNeue:size=14", height: 20)
            railClockRow(rows[3], fontKey: "rail-time-font", fallback: "HelveticaNeue:size=14", height: 20)
            railClockRow(rows[4], fontKey: "rail-period-font", fallback: "HelveticaNeue:size=10", height: 12)
        }
    }

    private func railClockRow(_ label: String, fontKey: String, fallback: String, height: Double) -> some View {
        var values = config
        values["format"] = .string("<label>")
        values["label"] = .string(label)
        values["font-0"] = .string(config[fontKey]?.stringValue ?? fallback)
        values["native-line-limit"] = .int(1)
        values.removeValue(forKey: "format-font-name")
        values.removeValue(forKey: "format-font-size")
        values.removeValue(forKey: "format-background")
        let spec = config[fontKey]?.stringValue ?? fallback
        let configuredSize = spec.components(separatedBy: "size=").last.flatMap(Double.init) ?? 14
        let size = GlanceFontPolicy.usesGlobal(config, appearance: configManager.config.appearance)
            ? Double(GlanceFontPolicy.font(configManager.config.appearance).fontSize) : configuredSize
        return PolybarFormattedContent(config: values, manager: configManager).frame(height: max(height, size * 1.3))
    }

    private func dateLineConfig(date: Bool) -> ConfigData {
        var values = config
        values["format"] = .string("<label>")
        values["label"] = .string(date ? "%date%" : "%time%")
        values["native-line-limit"] = .int(1)
        if date, let font = config["date-font"]?.stringValue {
            values["font-0"] = .string(font)
            values.removeValue(forKey: "format-font-name")
            values.removeValue(forKey: "format-font-size")
        }
        return values
    }
}

struct PolybarFormattedContent: View {
    let config: ConfigData
    @ObservedObject var manager: ConfigManager
    var value: Double = 0
    var tokens: [String: String] = [:]
    var state: String? = nil
    var action: ((String) -> Void)? = nil
    @State private var powerPresented = false
    @State private var launcherPresented = false
    @Environment(\.widgetFont) private var widgetFont
    @Environment(\.appearance) private var appearance
    @Environment(\.glanceCapsuleBackground) private var capsuleBackground
    @Environment(\.isBarPreviewRendering) private var preview

    private var values: ConfigData {
        var result = config
        // Formats retain symbolic palette references and recolor immediately
        // whenever the shared Pywal palette changes.
        let palette = manager.config.pywalColors?.colors ?? []
        for (key, item) in config {
            guard var text = item.stringValue else { continue }
            for index in (0..<16).reversed() {
                let reference = "pywal:\(index)"
                guard text.contains(reference) else { continue }
                let color = palette.indices.contains(index) ? palette[index] : (index == 0 ? .black : .white)
                let rgb = NSColor(color).usingColorSpace(.sRGB) ?? .white
                let hex = String(format: "#%02X%02X%02X", Int((rgb.redComponent * 255).rounded()), Int((rgb.greenComponent * 255).rounded()), Int((rgb.blueComponent * 255).rounded()))
                text = text.replacingOccurrences(of: reference, with: hex)
            }
            result[key] = .string(text)
        }
        if GlanceTransitionWidget.isDecoration(config) {
            if let before = result["transition-left-color"] { result["label-background"] = before }
            if let after = result["transition-right-color"] { result["label-foreground"] = after }
        }
        if let state {
            for (key, item) in Array(result) where key.hasPrefix("format-\(state)") {
                result[key.replacingOccurrences(of: "format-\(state)", with: "format")] = item
            }
        }
        // Keep the source glyph so removing an override restores it.
        for (key, item) in config where key.hasPrefix("native-symbol-") {
            let component = String(key.dropFirst("native-symbol-".count))
            if let symbol = item.stringValue, !symbol.isEmpty {
                let spacing = component == "format-prefix" ? "%{O\(config["native-icon-spacing"]?.doubleValue ?? 6)px}" : ""
                result[component] = .string("{{glance-icon:" + symbol + "}}" + spacing)
            }
        }
        if config["format-font-name"] != nil || config["format-font-size"] != nil {
            let font = PolybarScriptOptions(values: config).string("font-0") ?? ""
            let name = config["format-font-name"]?.stringValue ?? font.split(separator: ":").first.map(String.init) ?? widgetFont.fontName ?? ""
            let size = config["format-font-size"]?.doubleValue ?? Double(widgetFont.fontSize)
            result["font-0"] = .string(name + ":size=" + String(size))
        }
        // The outer module paints translucent backgrounds. Avoid an opaque
        // duplicate inside the formatted text when a module sets opacity.
        if let opacity = config["format-background-opacity"]?.doubleValue, opacity < 1 {
            result.removeValue(forKey: "format-background")
        }
        result["value"] = .double(value)
        if result["token-user"] == nil { result["token-user"] = .string(NSUserName()) }
        if result["token-host"] == nil { result["token-host"] = .string(ProcessInfo.processInfo.hostName.split(separator: ".").first.map(String.init) ?? "Mac") }
        for (key, text) in tokens { result["token-\(key)"] = .string(text) }
        if preview {
            // Sample values affect exports only; saved presets continue to use live data.
            for (key, text) in ProcessInfo.processInfo.environment where key.hasPrefix("GLANCE_PREVIEW_TOKEN_") {
                let token = key.dropFirst("GLANCE_PREVIEW_TOKEN_".count).lowercased().replacingOccurrences(of: "__", with: "-")
                result["token-" + token] = .string(text)
            }
        }
        return result
    }

    var body: some View {
        let resolved = values
        let pieces = PolybarScriptRenderer.render(output: tokens["output"] ?? "", config: resolved, actions: [:], counter: 0, pid: nil, failed: false)
        HStack(spacing: 0) {
            ForEach(Array(pieces.enumerated()), id: \.offset) { _, piece in
                switch piece {
                case let .text(text, style, actions):
                    let inlineUnitCount = GlanceInlineIcons.units(text).count
                    Button {
                        if let componentAction = actions[1] { perform(componentAction) }
                        else if let override = config["native-click-action"]?.stringValue, override != "module" {
                            perform(override, overrideDefault: true)
                        } else { perform(config["native-action"]?.stringValue ?? "") }
                    } label: {
                        componentText(text, style: style)
                            .font(componentFont(style))
                            .foregroundStyle(readableForeground(style))
                            .lineLimit(min(max(config["native-line-limit"]?.intValue ?? 1, 1), 8))
                            .truncationMode(.tail)
                            .multilineTextAlignment(config["native-text-alignment"]?.stringValue == "left" ? .leading : .center)
                            .fixedSize(horizontal: inlineUnitCount <= 12 && (!GlanceFontPolicy.usesGlobal(config, appearance: appearance) || text.allSatisfy(GlanceFontPolicy.isIcon)), vertical: (config["native-line-limit"]?.intValue ?? 1) > 1)
                            .modifier(GlanceTextOrientation(direction: config["native-text-direction"]?.stringValue ?? "horizontal"))
                            .frame(maxHeight: .infinity)
                            .background(style.background.map(Color.init(nsColor:)) ?? .clear)
                            .overlay(alignment: .bottom) { if let color = style.underline { Rectangle().fill(Color(nsColor: color)).frame(height: 2) } }
                            .overlay(alignment: .top) { if let color = style.overline { Rectangle().fill(Color(nsColor: color)).frame(height: 2) } }
                    }
                    .buttonStyle(.plain)
                    .layoutPriority(inlineUnitCount > 12 ? -1 : 0)
                case let .offset(width): Color.clear.frame(width: max(0, width))
                }
            }
        }
        .frame(maxHeight: .infinity)
        .modifier(PowerMenuPresentation(isPresented: $powerPresented))
        .modifier(AppLauncherPresentation(isPresented: $launcherPresented))
    }

    private func componentFont(_ style: PolybarScriptTextStyle) -> Font {
        if GlanceFontPolicy.usesGlobal(config, appearance: appearance) { return GlanceFontPolicy.font(appearance).toFont() }
        let font = style.font.map(Font.init) ?? widgetFont.toFont()
        guard let weight = config["format-font-weight"]?.intValue.flatMap(Font.Weight.fromInt) else { return font }
        return font.weight(weight)
    }

    private func componentText(_ text: String, style: PolybarScriptTextStyle) -> Text {
        let glyphFont = style.font.map(Font.init) ?? widgetFont.toFont()
        var remaining = text
        var label = Text("")
        while let start = remaining.range(of: "{{glance-icon:"),
              let end = remaining.range(of: "}}", range: start.upperBound..<remaining.endIndex) {
            label = label + GlanceFontPolicy.text(String(remaining[..<start.lowerBound]), glyphFont: glyphFont)
            let name = String(remaining[start.upperBound..<end.lowerBound])
            let size = min(max(config["native-icon-size"]?.doubleValue ?? widgetFont.fontSize, 6), 40)
            if let icon = GlanceInlineIcons.image(name, size: size) {
                label = label + Text(Image(nsImage: icon)).font(.system(size: size))
            }
            remaining = String(remaining[end.upperBound...])
        }
        return label + GlanceFontPolicy.text(remaining, glyphFont: glyphFont)
    }

    private func readableForeground(_ style: PolybarScriptTextStyle) -> Color {
        let foreground = style.foreground.map(Color.init(nsColor:)) ?? appearance.foregroundColor
        guard manager.config.rootToml.usePywal == true,
              !GlanceTransitionWidget.isDecoration(config),
              let background = style.background ?? capsuleBackground.map(NSColor.init), background.alphaComponent > 0.5 else { return foreground }
        func luminance(_ color: NSColor) -> Double {
            let rgb = color.usingColorSpace(.sRGB) ?? color
            func linear(_ v: CGFloat) -> Double { v <= 0.04045 ? Double(v / 12.92) : pow(Double((v + 0.055) / 1.055), 2.4) }
            return 0.2126 * linear(rgb.redComponent) + 0.7152 * linear(rgb.greenComponent) + 0.0722 * linear(rgb.blueComponent)
        }
        let bg = luminance(background)
        func contrast(_ color: NSColor) -> Double {
            let fg = luminance(color)
            return (max(bg, fg) + 0.05) / (min(bg, fg) + 0.05)
        }
        guard contrast(NSColor(foreground)) < 4.5 else { return foreground }
        let palette = manager.config.pywalColors?.colors ?? []
        let dark = palette.first ?? .black
        let light = palette.last ?? .white
        return contrast(NSColor(dark)) > contrast(NSColor(light)) ? dark : light
    }

    private func perform(_ command: String, overrideDefault: Bool = false) {
        if !overrideDefault, let action { action(command); return }
        if overrideDefault {
            if command == "launcher" { launcherPresented = true; return }
            if command == "power" { powerPresented = true; return }
            _ = GlanceModuleAction.perform(command, config: GlanceModuleAction.destinationConfig(config, prefix: "native-click-action-"))
            return
        }
        switch command {
        case "shuffle-colors": ConfigManager.shared.shuffleWidgetPalette()
        case "settings", "style": SettingsWindowController.shared.showSettings()
        case "launcher": launcherPresented = true
        case "terminal", "open-app": GlanceModuleAction.openApplication(config: config, fallback: command == "terminal" ? "/System/Applications/Utilities/Terminal.app" : nil)
        case "files": GlanceModuleAction.openResource(GlanceModuleAction.folder(config), config: config)
        case "browser": if let url = URL(string: config["action-url"]?.stringValue ?? "https://www.google.com") { GlanceModuleAction.openResource(url, config: config) }
        case "sound": _ = GlanceModuleAction.perform(command, config: config)
        case "notifications": if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") { NSWorkspace.shared.open(url) }
        case "bluetooth": if let url = URL(string: "x-apple.systempreferences:com.apple.Bluetooth-Settings.extension") { NSWorkspace.shared.open(url) }
        case "privacy": if let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension") { NSWorkspace.shared.open(url) }
        case "network": if let url = URL(string: "x-apple.systempreferences:com.apple.Network-Settings.extension") { NSWorkspace.shared.open(url) }
        case "power": powerPresented = true
        case "updates": if let url = URL(string: "x-apple.systempreferences:com.apple.Software-Update-Settings.extension") { NSWorkspace.shared.open(url) }
        default:
            if command.hasPrefix("https://"), let url = URL(string: command) { GlanceModuleAction.openResource(url, config: config) }
        }
    }
}

private struct PolybarSpacesContent: View {
    let config: ConfigData
    let manager: ConfigManager
    @StateObject private var spaces = SpacesViewModel()
    @State private var launcherPresented = false
    @State private var powerPresented = false
    @Environment(\.isBarPreviewRendering) private var preview

    var body: some View {
        if config["native-source"]?.stringValue == "window" {
            let focused = spaces.spaces.first(where: \.isFocused)?.windows.first(where: \.isFocused)
            PolybarFormattedContent(config: config, manager: manager, tokens: [
                "title": preview ? "Terminal" : focused?.title ?? NSWorkspace.shared.frontmostApplication?.localizedName ?? "",
                "name": preview ? "Desktop" : focused?.appName ?? NSWorkspace.shared.frontmostApplication?.localizedName ?? ""
            ])
        } else {
            let layout = config["native-orientation"]?.stringValue == "vertical"
                ? AnyLayout(VStackLayout(spacing: indicatorMode == "label" ? labelSpacing : indicatorSpacing)) : AnyLayout(HStackLayout(spacing: indicatorMode == "label" ? labelSpacing : indicatorSpacing))
            layout {
                ForEach(config["native-display-mode"]?.stringValue == "focused-only" ? spaces.spaces.filter(\.isFocused) : spaces.spaces) { space in
                    let state = space.isFocused ? (config["label-active"] != nil ? "active" : "focused")
                        : (space.windows.isEmpty ? "empty" : "occupied")
                    let icon = workspaceIcon(space.id)
                    if indicatorMode == "label" {
                        let values = workspaceConfig(state, id: space.id)
                        let radius = min(max(config["workspace-label-radius"]?.doubleValue ?? 0, 0), 40)
                        let background = radius > 0 ? PolybarModuleStyle.color(values["label-" + state + "-background"]?.stringValue, palette: manager.config.pywalColors?.colors ?? []) : nil
                        let labelValues = roundedWorkspaceConfig(values, state: state, enabled: background != nil)
                        PolybarFormattedContent(config: labelValues, manager: manager, tokens: [
                            "name": space.id, "index": space.id, "icon": icon,
                            "nwin": String(space.windows.count)
                        ], action: { _ in spaces.switchToSpace(space, needWindowFocus: true) })
                        .frame(minWidth: min(max((space.isFocused ? config["workspace-label-active-width"]?.doubleValue : nil) ?? config["workspace-label-width"]?.doubleValue ?? 0, 0), 80))
                        .frame(height: background != nil ? min(max(config["workspace-label-height"]?.doubleValue ?? 26, 8), 80) : nil)
                        .background(background ?? .clear, in: RoundedRectangle(cornerRadius: radius))
                    } else {
                        Button {
                            let command = config["native-click-action"]?.stringValue ?? "module"
                            if command == "module" { spaces.switchToSpace(space, needWindowFocus: true) }
                            else if command == "launcher" { launcherPresented = true }
                            else if command == "power" { powerPresented = true }
                            else { _ = GlanceModuleAction.perform(command, config: GlanceModuleAction.destinationConfig(config, prefix: "native-click-action-")) }
                        } label: {
                            let diameter = min(max(config["workspace-dot-size"]?.doubleValue ?? 12, 4), 32)
                            let width = space.isFocused && indicatorMode == "pill"
                                ? min(max(config["workspace-active-width"]?.doubleValue ?? 26, diameter), 80) : diameter
                            let color = indicatorColor(state: state, id: space.id).opacity(space.isFocused ? 1 : min(max(config["workspace-inactive-opacity"]?.doubleValue ?? 1, 0), 1))
                            Capsule()
                                .fill((indicatorMode == "ring" && !space.isFocused) || (indicatorMode == "ring-active" && space.isFocused) ? .clear : color)
                                .overlay { if indicatorMode == "ring" || (indicatorMode == "ring-active" && space.isFocused) { Capsule().strokeBorder(color, lineWidth: 1.5) } }
                                .frame(width: width, height: diameter)
                                .frame(minWidth: config["native-orientation"]?.stringValue == "vertical" ? 16 : max(diameter, config["workspace-hit-width"]?.doubleValue ?? 16), minHeight: config["native-orientation"]?.stringValue == "vertical" ? max(diameter, config["workspace-hit-height"]?.doubleValue ?? 24) : 24)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Space " + space.id)
                        .accessibilityValue(space.isFocused ? "Active" : "")
                    }
                }
            }
            .frame(maxHeight: config["native-orientation"]?.stringValue == "vertical" ? nil : .infinity)
            .modifier(AppLauncherPresentation(isPresented: $launcherPresented))
            .modifier(PowerMenuPresentation(isPresented: $powerPresented))
        }
    }

    private var indicatorMode: String { config["workspace-indicator"]?.stringValue ?? "label" }
    private var indicatorSpacing: CGFloat { min(max(config["workspace-dot-spacing"]?.doubleValue ?? 4, 0), 32) }
    private var labelSpacing: CGFloat { min(max(config["workspace-label-spacing"]?.doubleValue ?? (config["native-orientation"]?.stringValue == "vertical" ? 3 : 0), 0), 32) }
    private func indicatorColor(state: String, id: String) -> Color {
        let value = config["workspace-color-" + id]?.stringValue
            ?? config["label-" + state + "-foreground"]?.stringValue
            ?? config["format-foreground"]?.stringValue
        return PolybarModuleStyle.color(value, palette: manager.config.pywalColors?.colors ?? [])
            ?? manager.config.appearance.foregroundColor
    }

    private func workspaceConfig(_ state: String, id: String) -> ConfigData {
        var values = config
        let name = "label-" + state
        values["format"] = .string("<" + name + ">")
        if values[name] == nil { values[name] = values["label-occupied"] ?? .string("%index%") }
        if let color = values["workspace-color-" + id] { values[name + "-foreground"] = color }
        return values
    }

    private func roundedWorkspaceConfig(_ values: ConfigData, state: String, enabled: Bool) -> ConfigData {
        guard enabled else { return values }
        var result = values
        result.removeValue(forKey: "label-" + state + "-background")
        return result
    }

    private func workspaceIcon(_ id: String) -> String {
        for (key, value) in config where key.hasPrefix("ws-icon-") || key.hasPrefix("icon-") {
            let parts = (value.stringValue ?? "").split(separator: ";", maxSplits: 1)
            if parts.count == 2, parts[0] == id { return String(parts[1]) }
        }
        return config["ws-icon-default"]?.stringValue ?? config["icon-default"]?.stringValue ?? id
    }
}

private struct PolybarSystemContent: View {
    let config: ConfigData
    let manager: ConfigManager
    @ObservedObject private var system = SystemMonitorViewModel.shared
    @Environment(\.isBarPreviewRendering) private var preview
    var body: some View {
        let memory = config["native-source"]?.stringValue == "memory"
        let value = preview ? (memory ? 42.0 : 18.0) : (memory ? system.memoryUsagePercent : system.cpuUsage)
        let used = preview ? 6.7 : system.memoryUsedGB
        let total = preview ? 16.0 : system.memoryTotalGB
        PolybarFormattedContent(config: config, manager: manager, value: value, tokens: [
            "gb_used": String(format: "%.1f", used), "gb_total": String(format: "%.1f", total),
            "mb_used": String(Int(used * 1024)), "gb_free": String(format: "%.1f", total - used)
        ].merging(Dictionary(uniqueKeysWithValues: (preview ? [15.0, 22.0, 29.0, 36.0] : system.coreUsage).enumerated().map { index, usage in
            ("percentage-core\(index + 1)", String(Int(preview ? Double(15 + index * 7) : usage)))
        })) { a, _ in a })
    }
}

private struct PolybarDiskContent: View {
    let config: ConfigData
    let manager: ConfigManager
    @StateObject private var disk = DiskViewModel()
    @Environment(\.isBarPreviewRendering) private var preview
    var body: some View {
        PolybarFormattedContent(config: config, manager: manager, value: preview ? 36 : disk.usagePercent, tokens: [
            "used-gb": String(format: "%.0f GB", preview ? 180.0 : disk.usedGB),
            "free-gb": String(format: "%.0f GB", preview ? 320.0 : disk.freeGB),
            "free": String(format: "%.1f GiB", preview ? 320.0 : disk.freeGB),
            "used": String(format: "%.1f GiB", preview ? 180.0 : disk.usedGB),
            "total": String(format: "%.1f GiB", preview ? 500.0 : disk.totalGB), "mountpoint": "/"
        ], state: "mounted")
    }
}

private struct PolybarVolumeContent: View {
    let config: ConfigData
    let manager: ConfigManager
    let preview: Bool
    @StateObject private var volume: VolumeViewModel
    init(config: ConfigData, manager: ConfigManager, preview: Bool) {
        self.config = config; self.manager = manager; self.preview = preview
        _volume = StateObject(wrappedValue: VolumeViewModel(previewMode: preview))
    }
    var body: some View {
        PolybarFormattedContent(config: config, manager: manager, value: preview ? 55 : Double(volume.volumePercent), state: volume.isMuted && !preview ? "muted" : "volume", action: { _ in volume.toggleMute() })
            .overlay {
                if !preview { VolumeScrollOverlay { delta in volume.adjustVolume(by: delta > 0 ? -0.05 : 0.05) } }
            }
    }
}

private struct PolybarBrightnessContent: View {
    let config: ConfigData
    let manager: ConfigManager
    @StateObject private var brightness: BrightnessViewModel
    let preview: Bool
    init(config: ConfigData, manager: ConfigManager, preview: Bool) {
        self.config = config; self.manager = manager; self.preview = preview
        _brightness = StateObject(wrappedValue: BrightnessViewModel(previewMode: preview))
    }
    var body: some View {
        PolybarFormattedContent(config: config, manager: manager, value: preview ? 70 : Double(brightness.brightness * 100),
                                tokens: !preview && !brightness.isAvailable ? ["percentage": "—"] : [:])
            .overlay {
                if !preview && brightness.isAvailable { VolumeScrollOverlay { delta in brightness.adjustBrightness(by: delta > 0 ? -0.05 : 0.05) } }
            }
    }
}

private struct PolybarNetworkContent: View {
    let config: ConfigData
    let manager: ConfigManager
    @ObservedObject private var network = NetworkStatusViewModel.shared
    @Environment(\.isBarPreviewRendering) private var preview
    @State private var throughputID = UUID()
    @Environment(\.barCollectorsActive) private var collectorsActive
    private var needsThroughput: Bool {
        !preview && collectorsActive && config.values.contains { value in
            guard let text = value.stringValue else { return false }
            return text.contains("%downspeed") || text.contains("%upspeed")
        }
    }
    var body: some View {
        PolybarFormattedContent(config: config, manager: manager, value: preview ? 80 : network.signalPercentage ?? 0, tokens: [
            "percentage": preview ? "80" : network.signalPercentage.map { String(Int($0.rounded())) } ?? "—",
            "essid": preview ? "Wi-Fi" : network.ssid, "local_ip": (preview ? "10.0.2.15" : network.localIP),
            "downspeed-compact": String(format: "%.0f K", preview ? 180.0 : network.downloadSpeed / 1024),
            "upspeed-compact": String(format: "%.0f K", preview ? 24.0 : network.uploadSpeed / 1024),
            "downspeed": String(format: "%.0f KiB/s", preview ? 180.0 : network.downloadSpeed / 1024),
            "upspeed": String(format: "%.0f KiB/s", preview ? 24.0 : network.uploadSpeed / 1024),
            "output": preview ? "Connected" : network.wifiState.rawValue
        ], state: preview || network.isWiFiAssociated ? "connected" : "disconnected")
        .onAppear { network.setThroughputDemand(throughputID, enabled: needsThroughput) }
        .onChange(of: needsThroughput) { _, enabled in network.setThroughputDemand(throughputID, enabled: enabled) }
        .onDisappear { network.setThroughputDemand(throughputID, enabled: false) }
    }
}

private struct PolybarMusicContent: View {
    let config: ConfigData
    let manager: ConfigManager
    @ObservedObject private var player = NowPlayingManager.shared
    @Environment(\.isBarPreviewRendering) private var preview
    var body: some View {
        let song = player.nowPlaying
        let env = ProcessInfo.processInfo.environment
        let position: Double? = preview ? (env["GLANCE_PREVIEW_TRACK_POSITION"].flatMap(Double.init) ?? 75) : song?.position
        let duration: Double? = preview ? (env["GLANCE_PREVIEW_TRACK_DURATION"].flatMap(Double.init) ?? 240) : song?.duration
        let playing = preview || song?.state == .playing
        var values = GlanceMusicFormatting.applying(to: config)
        // The source's <toggle> selects one of its configured icon glyphs.
        let toggleIcon = playing ? "icon-pause" : "icon-play"
        values["native-symbol-label-toggle"] = values["native-symbol-" + toggleIcon]
        values["label-toggle"] = values[toggleIcon] ?? .string(playing ? "Ⅱ" : "▶")
        for (key, command) in [("prev", "previous"), ("next", "next"), ("stop", "stop"), ("play", "toggle"), ("pause", "toggle")] {
            if let glyph = values["icon-" + key]?.stringValue {
                let symbol = values["native-symbol-icon-" + key]?.stringValue
                let icon = symbol.map { "{{glance-icon:" + $0 + "}}" } ?? glyph
                values["label-" + key] = .string("%{A1:" + command + ":}" + icon + "%{A}")
                for field in ["foreground", "background", "font", "padding"] {
                    if let value = values["icon-" + key + "-" + field] { values["label-" + key + "-" + field] = value }
                }
            }
        }
        for field in ["foreground", "background", "font", "padding"] {
            if let value = values[toggleIcon + "-" + field] { values["label-toggle-" + field] = value }
        }
        let title = preview ? (env["GLANCE_PREVIEW_TRACK_TITLE"] ?? "Ever Falling") : song?.title ?? "No music"
        let artist = preview ? (env["GLANCE_PREVIEW_TRACK_ARTIST"] ?? "Amon Tobin") : song?.artist ?? ""
        let album = preview ? (env["GLANCE_PREVIEW_TRACK_ALBUM"] ?? "Foley Room") : song?.album ?? ""
        let progress = duration.flatMap { $0 > 0 ? (position ?? 0) / $0 * 100 : nil } ?? 0
        return PolybarFormattedContent(config: values, manager: manager, value: progress, tokens: [
            "title": title, "artist": artist, "album": album,
            "song-details": GlanceMusicFormatting.details(title: title, artist: artist, album: album, config: config),
            "elapsed": GlanceMusicFormatting.time(position), "total": GlanceMusicFormatting.time(duration)
        ], state: preview || song != nil ? "online" : "offline", action: { command in
            switch command {
            case "previous": MediaRemoteProvider.shared.sendCommand(.previousTrack)
            case "next": MediaRemoteProvider.shared.sendCommand(.nextTrack)
            case "stop": MediaRemoteProvider.shared.sendCommand(.pause)
            default: MediaRemoteProvider.shared.sendCommand(.togglePlayPause)
            }
        })
    }
}

private struct PolybarTemperatureContent: View {
    let config: ConfigData
    let manager: ConfigManager
    @ObservedObject private var thermal = ThermalManager.shared
    @Environment(\.isBarPreviewRendering) private var preview
    var body: some View {
        let temp = preview ? 48 : Int(thermal.cpuTemperature)
        PolybarFormattedContent(config: config, manager: manager, value: Double(temp), tokens: ["temperature-c": "\(temp)", "temperature-f": "\(temp * 9 / 5 + 32)"])
    }
}

private struct PolybarKeyboardContent: View {
    let config: ConfigData
    let manager: ConfigManager
    @StateObject private var keyboard = InputLanguageViewModel()
    var body: some View {
        PolybarFormattedContent(config: config, manager: manager, tokens: ["layout": keyboard.languageCode, "layout-lower": keyboard.languageCode.lowercased(), "name": keyboard.fullName])
    }
}

private struct GlanceFormattedBluetooth: View {
    let config: ConfigData
    let manager: ConfigManager
    @ObservedObject private var bluetooth = BluetoothViewModel.shared
    @Environment(\.isBarPreviewRendering) private var preview
    var body: some View {
        PolybarFormattedContent(config: config, manager: manager,
            tokens: ["power": preview || bluetooth.isPoweredOn ? "on" : "off", "count": String(preview ? 1 : bluetooth.connectedCount),
                     "output": preview || bluetooth.connectedCount > 0 ? "Connected" : "Standby"],
            action: { _ in
                if let url = URL(string: "x-apple.systempreferences:com.apple.Bluetooth-Settings.extension") { NSWorkspace.shared.open(url) }
            })
    }
}

/// Reads gain without recording audio. Devices without a gain control display
/// an unavailable marker instead of a fabricated percentage.
private struct GlanceFormattedInputGain: View {
    let config: ConfigData
    let manager: ConfigManager
    @Environment(\.isBarPreviewRendering) private var preview
    var body: some View {
        TimelineView(.periodic(from: .now, by: 4)) { _ in
            let gain = preview ? 1.0 : Self.inputGain()
            PolybarFormattedContent(config: config, manager: manager, value: (gain ?? 0) * 100,
                tokens: ["percentage": gain.map { String(Int(($0 * 100).rounded())) } ?? "—"],
                action: { _ in
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Sound-Settings.extension") { NSWorkspace.shared.open(url) }
                })
        }
    }
    private static func inputGain() -> Double? {
        var device: AudioObjectID = 0
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device) == noErr,
              device != kAudioObjectUnknown else { return nil }
        for selector in [kAudioHardwareServiceDeviceProperty_VirtualMainVolume, kAudioDevicePropertyVolumeScalar] {
            for element in [kAudioObjectPropertyElementMain, AudioObjectPropertyElement(1)] {
                address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeInput, mElement: element)
                var value: Float32 = 0
                size = UInt32(MemoryLayout<Float32>.size)
                if AudioObjectHasProperty(device, &address),
                   AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr {
                    return min(max(Double(value), 0), 1)
                }
            }
        }
        return nil
    }
}

private struct GlanceFormattedUpdateCount: View {
    let config: ConfigData
    let manager: ConfigManager
    let preview: Bool
    @StateObject private var updater: AppUpdater
    init(config: ConfigData, manager: ConfigManager, preview: Bool) {
        self.config = config; self.manager = manager; self.preview = preview
        _updater = StateObject(wrappedValue: AppUpdater(checkAutomatically: !preview))
    }
    var body: some View {
        PolybarFormattedContent(config: config, manager: manager,
            tokens: ["count": preview ? "0" : updater.latestVersion == nil ? "—" : updater.updateAvailable ? "1" : "0"],
            action: { _ in NSWorkspace.shared.open(AppUpdater.releasesURL) })
    }
}

/// The user's own login picture, never the portrait from a reference image.
private struct GlanceUserBadge: View {
    let config: ConfigData
    @State private var avatar: NSImage?
    @State private var launcherPresented = false
    @State private var powerPresented = false
    private static let exportAvatar = loginImage()
    var body: some View {
        let size = min(max(config["user-avatar-size"]?.doubleValue ?? 24, 16), 40)
        let picture = avatar ?? (CommandLine.arguments.contains("--export-bar") && config["user-show-photo"]?.boolValue != false ? Self.exportAvatar : nil)
        Button {
            let command = config["native-click-action"]?.stringValue ?? "module"
            if command == "module" || command == "launcher" { launcherPresented = true }
            else if command == "power" { powerPresented = true }
            else { _ = GlanceModuleAction.perform(command, config: GlanceModuleAction.destinationConfig(config, prefix: "native-click-action-")) }
        } label: {
            Group {
                if config["user-show-photo"]?.boolValue != false, let picture {
                    Image(nsImage: picture).resizable().scaledToFill()
                } else {
                    Image(systemName: config["native-symbol-label-prefix"]?.stringValue ?? "person.crop.circle.fill")
                        .resizable().scaledToFit()
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(NSFullUserName())
        .modifier(PowerMenuPresentation(isPresented: $powerPresented))
        .modifier(AppLauncherPresentation(isPresented: $launcherPresented))
        .task {
            guard !CommandLine.arguments.contains("--export-bar"), avatar == nil,
                  config["user-show-photo"]?.boolValue != false else { return }
            let image = await Task.detached(priority: .utility) { Self.loginImage() }.value
            avatar = image
        }
    }
    nonisolated private static func loginImage() -> NSImage? {
        do {
            let node = try ODNode(session: ODSession.default(), type: UInt32(kODNodeTypeLocalNodes))
            let record = try node.record(withRecordType: kODRecordTypeUsers, name: NSUserName(),
                                        attributes: [kODAttributeTypeJPEGPhoto, kODAttributeTypePicture])
            if let data = try record.values(forAttribute: kODAttributeTypeJPEGPhoto).first as? Data,
               let image = NSImage(data: data) { return image }
            if let path = try record.values(forAttribute: kODAttributeTypePicture).first as? String {
                return NSImage(contentsOfFile: path)
            }
        } catch { return nil }
        return nil
    }
}
