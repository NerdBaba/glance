import SwiftUI

struct MenuBarView: View {
    @ObservedObject var configManager = ConfigManager.shared

    private var shouldShowSystemBanner: Bool {
        ProcessInfo.processInfo.environment["GLANCE_PREVIEW_BAR_PATH"] == nil
            && !CommandLine.arguments.contains("--export-bar")
            && !CommandLine.arguments.contains("--preview-panel")
    }

    private var isPreviewRender: Bool {
        ProcessInfo.processInfo.environment["GLANCE_PREVIEW_BAR_PATH"] != nil
            || CommandLine.arguments.contains("--export-bar")
            || CommandLine.arguments.contains("--preview-panel")
    }

    var body: some View {
        let _ = configManager.config
        let items = configManager.config.rootToml.widgets?.displayed ?? []
        let appearance = configManager.config.appearance
        let fg = configManager.config.experimental.foreground
        let formation = fg.formation

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
            switch formation {
            case .full:
                fullBar(items: items, appearance: appearance, fg: fg)
            case .floating:
                floatingBar(items: items, appearance: appearance, fg: fg)
            case .islands:
                islandsBar(items: items, appearance: appearance, fg: fg)
            case .pills:
                pillsBar(items: items, appearance: appearance, fg: fg)
            }
        }
        .foregroundStyle(appearance.foregroundColor)
        .frame(height: max(fg.resolveHeight(), 1.0))
        .frame(maxWidth: .infinity)
        .padding(.horizontal, fg.margin)
        .background(.black.opacity(0.001))
        .contextMenu {
            Button("Settings...") {
                SettingsWindowController.shared.showSettings()
            }
            Divider()
            Button("Quit Glance") {
                NSApplication.shared.terminate(nil)
            }
        }
        .environment(\.barStyle, configManager.config.barStyle)
        .environment(\.appearance, appearance)
        .environment(\.barFont, appearance.barFont)
        .environment(\.widgetFont, appearance.useSingleFont ? appearance.barFont : appearance.widgetFont)
        .environment(\.resolvedForegroundConfig, resolvedFG)
        .environment(\.isBarPreviewRendering, isPreviewRender)
        .preferredColorScheme(.dark)
    }

    // MARK: - Full Monobar

    @ViewBuilder
    private func fullBar(items: [TomlWidgetItem], appearance: AppearanceConfig, fg: ForegroundConfig) -> some View {
        let showBg = fg.widgetsBackground.displayed
        HStack(spacing: 0) {
            widgetContent(items: items, fg: fg)
        }
        .padding(.horizontal, fg.horizontalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetStyle(appearance, heightOverride: fg.resolveHeight(), showBackground: showBg)
    }

    // MARK: - Floating Monobar

    @ViewBuilder
    private func floatingBar(items: [TomlWidgetItem], appearance: AppearanceConfig, fg: ForegroundConfig) -> some View {
        let showBg = fg.widgetsBackground.displayed
        let barContent = HStack(spacing: 0) {
            widgetContent(items: items, fg: fg)
        }
        .padding(.horizontal, fg.horizontalPadding)
        .frame(width: fg.floatingWidth > 0 ? fg.floatingWidth : nil)
        .frame(maxWidth: fg.floatingWidth > 0 ? nil : .infinity)
        .frame(height: capsuleHeight(fg))
        .widgetStyle(appearance, heightOverride: capsuleHeight(fg), showBackground: showBg)

        if fg.floatingWidth > 0 {
            HStack(spacing: 0) {
                if fg.horizontalAlignment != "left" { Spacer(minLength: 0) }
                barContent
                if fg.horizontalAlignment != "right" { Spacer(minLength: 0) }
            }
            .frame(maxWidth: .infinity)
        } else {
            barContent
        }
    }

    // MARK: - Islands

    @ViewBuilder
    private func islandsBar(items: [TomlWidgetItem], appearance: AppearanceConfig, fg: ForegroundConfig) -> some View {
        let sections = splitBySpacer(items)
        let hasBanner = items.contains(where: { $0.id == "system-banner" })
        let showBg = fg.widgetsBackground.displayed

        Group {
            if sections.count == 3 {
                ZStack {
                    HStack(spacing: fg.spacing) {
                        ForEach(Array(sections[0].enumerated()), id: \.offset) { _, item in
                            islandItem(item, appearance: appearance, fg: fg, showBg: showBg)
                        }
                        Spacer(minLength: 0)
                    }
                    HStack(spacing: fg.spacing) {
                        ForEach(Array(sections[1].enumerated()), id: \.offset) { _, item in
                            islandItem(item, appearance: appearance, fg: fg, showBg: showBg)
                        }
                    }
                    HStack(spacing: fg.spacing) {
                        Spacer(minLength: 0)
                        ForEach(Array(sections[2].enumerated()), id: \.offset) { _, item in
                            islandItem(item, appearance: appearance, fg: fg, showBg: showBg)
                        }
                        if shouldShowSystemBanner && !hasBanner {
                            SystemBannerWidget(withLeftPadding: true)
                        }
                    }
                }
            } else {
                HStack(spacing: fg.spacing) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        islandItem(item, appearance: appearance, fg: fg, showBg: showBg)
                    }
                    if shouldShowSystemBanner && !hasBanner {
                        SystemBannerWidget(withLeftPadding: true)
                    }
                }
            }
        }
        .animation(.smooth(duration: 0.3), value: items.map(\.id))
        .padding(.horizontal, fg.horizontalPadding)
    }

    @ViewBuilder
    private func islandItem(_ item: TomlWidgetItem, appearance: AppearanceConfig, fg: ForegroundConfig, showBg: Bool) -> some View {
        if item.id == "spacer" {
            Spacer().frame(minWidth: 50, maxWidth: .infinity)
        } else if item.id == "divider" {
            Rectangle()
                .fill(appearance.accentColor.opacity(0.4))
                .frame(width: 2, height: 15)
                .clipShape(Capsule())
        } else {
            let h = capsuleHeight(fg)
            moduleView(for: item, height: h)
                .widgetStyle(appearance, heightOverride: h, showBackground: showBg)
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
        }
    }

    // MARK: - Pills

    @ViewBuilder
    private func pillsBar(items: [TomlWidgetItem], appearance: AppearanceConfig, fg: ForegroundConfig) -> some View {
        let groups = splitIntoGroups(items)
        let height = capsuleHeight(fg)
        let nonSpacerGroups = groups.filter { !$0.isSpacer }
        let spacerCount = groups.filter { $0.isSpacer }.count
        let hasBanner = items.contains(where: { $0.id == "system-banner" })

        Group {
            if spacerCount == 2 && nonSpacerGroups.count == 2 {
                ZStack(alignment: .leading) {
                    pillCapsule(
                        nonSpacerGroups[0], height: height, appearance: appearance, fg: fg,
                        minWidth: fg.leftGroupWidth, alignment: .leading)
                        .padding(.leading, fg.leftGroupOffset)

                    HStack(spacing: fg.gap) {
                        Spacer(minLength: 0)
                        pillCapsule(
                            nonSpacerGroups[1], height: height, appearance: appearance, fg: fg,
                            minWidth: fg.rightGroupWidth, alignment: .trailing)
                    }
                }
            } else if spacerCount == 2 && nonSpacerGroups.count == 3 {
                ZStack {
                    HStack(spacing: fg.gap) {
                        pillCapsule(
                            nonSpacerGroups[0], height: height, appearance: appearance, fg: fg,
                            minWidth: fg.leftGroupWidth, alignment: .leading)
                        Spacer(minLength: 0)
                    }
                    HStack(spacing: fg.gap) {
                        pillCapsule(
                            nonSpacerGroups[1], height: height, appearance: appearance, fg: fg,
                            minWidth: fg.centerGroupWidth, alignment: .center)
                    }
                    .offset(x: fg.centerGroupOffset)
                    .zIndex(1)
                    HStack(spacing: fg.gap) {
                        Spacer(minLength: 0)
                        pillCapsule(
                            nonSpacerGroups[2], height: height, appearance: appearance, fg: fg,
                            minWidth: fg.rightGroupWidth, alignment: .trailing)
                        if shouldShowSystemBanner && !hasBanner {
                            SystemBannerWidget(withLeftPadding: false)
                        }
                    }
                }
            } else {
                HStack(spacing: fg.gap) {
                    ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                        if group.isSpacer {
                            Spacer(minLength: 0)
                        } else {
                            pillCapsule(group, height: height, appearance: appearance, fg: fg)
                        }
                    }
                    if shouldShowSystemBanner && !hasBanner {
                        SystemBannerWidget(withLeftPadding: false)
                    }
                }
            }
        }
        .animation(.smooth(duration: 0.3), value: items.map(\.id))
    }

    @ViewBuilder
    private func pillCapsule(
        _ group: WidgetGroup,
        height: CGFloat,
        appearance: AppearanceConfig,
        fg: ForegroundConfig,
        minWidth: CGFloat = 0,
        alignment: Alignment = .leading
    ) -> some View {
        let showBg = fg.widgetsBackground.displayed
        let hasSegmentBackground = group.items.contains {
            PolybarModuleStyle.resolve(item: $0, configManager: configManager).hasSegmentBackground
        }
        let fixedWidth = group.items.first.map {
            configManager.resolvedWidgetConfig(for: $0)["group-fixed-width"]?.boolValue ?? false
        } ?? false
        HStack(spacing: hasSegmentBackground ? 0 : fg.spacing) {
            ForEach(Array(group.items.enumerated()), id: \.offset) { _, item in
                moduleView(for: item, height: height)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .padding(.horizontal, hasSegmentBackground ? 0 : 8)
        .frame(minWidth: minWidth, maxWidth: fixedWidth && minWidth > 0 ? minWidth : nil, alignment: hasSegmentBackground ? .leading : alignment)
        .frame(height: height)
        .widgetStyle(appearance, heightOverride: height, showBackground: showBg)
        .overlay {
            if let first = group.items.first {
                let values = configManager.resolvedWidgetConfig(for: first)
                let width = min(max(values["group-border-width"]?.doubleValue ?? 0, 0), 8)
                if let color = PolybarModuleStyle.color(values["group-border-color"]?.stringValue, palette: configManager.config.pywalColors?.colors ?? []), width > 0 {
                    RoundedRectangle(cornerRadius: appearance.resolvedWidgetCornerRadius(height: height))
                        .strokeBorder(color, lineWidth: width)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    // MARK: - Shared Helpers

    private func capsuleHeight(_ fg: ForegroundConfig) -> CGFloat {
        max(fg.resolveHeight() - 4, 1)
    }

    private func splitBySpacer(_ items: [TomlWidgetItem]) -> [[TomlWidgetItem]] {
        var sections: [[TomlWidgetItem]] = [[]]
        for item in items {
            if item.id == "spacer" {
                sections.append([])
            } else {
                sections[sections.count - 1].append(item)
            }
        }
        return sections
    }

    @ViewBuilder
    private func widgetRow(_ items: [TomlWidgetItem]) -> some View {
        ForEach(Array(items.enumerated()), id: \.offset) { _, item in
            moduleView(for: item)
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
        }
    }

    @ViewBuilder
    private func widgetContent(items: [TomlWidgetItem], fg: ForegroundConfig) -> some View {
        let sections = splitBySpacer(items)
        let hasBanner = items.contains(where: { $0.id == "system-banner" })

        if sections.count == 3 {
            ZStack {
                HStack(spacing: fg.spacing) {
                    widgetRow(sections[0])
                    Spacer(minLength: 0)
                }
                HStack(spacing: fg.spacing) {
                    widgetRow(sections[1])
                }
                .offset(x: fg.centerGroupOffset)
                HStack(spacing: fg.spacing) {
                    Spacer(minLength: 0)
                    widgetRow(sections[2])
                    if shouldShowSystemBanner && !hasBanner {
                        SystemBannerWidget(withLeftPadding: true)
                    }
                }
            }
            .animation(.smooth(duration: 0.3), value: items.map(\.id))
        } else {
            HStack(spacing: fg.spacing) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    moduleView(for: item)
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }
            .animation(.smooth(duration: 0.3), value: items.map(\.id))
            if shouldShowSystemBanner && !hasBanner {
                SystemBannerWidget(withLeftPadding: true)
            }
        }
    }

    // MARK: - Group Splitting

    private struct WidgetGroup {
        let items: [TomlWidgetItem]
        let isSpacer: Bool
        static func spacer() -> WidgetGroup {
            WidgetGroup(items: [], isSpacer: true)
        }
    }

    private func splitIntoGroups(_ items: [TomlWidgetItem]) -> [WidgetGroup] {
        var groups: [WidgetGroup] = []
        var currentGroup: [TomlWidgetItem] = []
        for item in items {
            if item.id == "spacer" {
                if !currentGroup.isEmpty {
                    groups.append(WidgetGroup(items: currentGroup, isSpacer: false))
                    currentGroup = []
                }
                groups.append(.spacer())
            } else if item.id == "divider" {
                currentGroup.append(item)
            } else {
                currentGroup.append(item)
            }
        }
        if !currentGroup.isEmpty {
            groups.append(WidgetGroup(items: currentGroup, isSpacer: false))
        }
        return groups
    }

    // MARK: - Widget Builder

    @ViewBuilder
    private func buildView(for item: TomlWidgetItem) -> some View {
        let config = ConfigProvider(config: configManager.resolvedWidgetConfig(for: item))
        let moduleStyle = PolybarModuleStyle.resolve(item: item, configManager: configManager)
        let fgColor = moduleStyle.foreground ?? configManager.config.widgetForegroundColors[item.id]
        let widget = widgetView(for: item, config: config)
        if let fgColor {
            widget.foregroundStyle(fgColor)
        } else {
            widget
        }
    }

    @ViewBuilder
    private func moduleView(for item: TomlWidgetItem, height: CGFloat? = nil) -> some View {
        let style = PolybarModuleStyle.resolve(item: item, configManager: configManager)
        let appearance = configManager.config.appearance
        let widget = buildView(for: item)
            .tracking(min(max(configManager.resolvedWidgetConfig(for: item)["format-tracking"]?.doubleValue ?? 0, -3), 6))
            .offset(y: min(max(configManager.resolvedWidgetConfig(for: item)["format-offset-y"]?.doubleValue ?? 0, -12), 12))
            .environment(\.usesPolybarModuleLayout, style.usesModuleLayout)
            .environment(\.widgetFont, style.font ?? (appearance.useSingleFont ? appearance.barFont : appearance.widgetFont))
        if style.hasSegmentStyle {
            if let height {
                widget
                    .frame(height: height)
                    .polybarModuleStyle(style)
                    .layoutPriority(style.minimumWidth > 0 ? 10 : 1)
            } else {
                widget
                    .frame(maxHeight: .infinity)
                    .polybarModuleStyle(style)
                    .layoutPriority(style.minimumWidth > 0 ? 10 : 1)
            }
        } else {
            widget
        }
    }

    @ViewBuilder
    private func widgetView(for item: TomlWidgetItem, config: ConfigProvider) -> some View {
        switch item.id {
        case "default.spaces":
            SpacesWidget().environmentObject(config)
        case "default.network":
            if isPreviewRender && config.config["display-mode"]?.stringValue == "ip" {
                NetworkIPAddressContent(config: config, address: ProcessInfo.processInfo.environment["GLANCE_PREVIEW_LOCAL_IP"] ?? "10.0.2.15")
            } else {
                NetworkWidget().environmentObject(config)
            }
        case "default.battery":
            BatteryWidget().environmentObject(config)
        case "default.time":
            TimeWidget(configProvider: config)
        case "default.nowplaying":
            if isPreviewRender {
                BarPreviewNowPlaying(config: config)
            } else {
                NowPlayingWidget().environmentObject(config)
            }
        case "default.mediacontrols":
            if isPreviewRender {
                BarPreviewMediaControls(config: config)
            } else {
                MediaControlsWidget().environmentObject(config)
            }
        case "default.volume":
            VolumeWidget().environmentObject(config)
        case "default.activeapp":
            if isPreviewRender {
                BarPreviewActiveApp()
            } else {
                ActiveAppWidget().environmentObject(config)
            }
        case "default.launcher":
            LauncherWidget(config: config)
        case "default.power":
            PowerWidget(config: config)
        case "default.weather":
            WeatherWidget().environmentObject(config)
        case "default.systemmonitor":
            SystemMonitorWidget().environmentObject(config)
        case "default.disk":
            DiskWidget().environmentObject(config)
        case "default.fan":
            FanWidget().environmentObject(config)
        case "default.energy":
            EnergyWidget().environmentObject(config)
        case "default.pomodoro":
            PomodoroWidget().environmentObject(config)
        case "default.inputlanguage":
            InputLanguageWidget()
        case "default.brightness":
            BrightnessWidget().environmentObject(config)
        case "default.clipboard":
            ClipboardWidget().environmentObject(config)
        case "default.bluetooth":
            BluetoothWidget().environmentObject(config)
        case "default.temperature":
            TemperatureWidget().environmentObject(config)
        case "spacer":
            if isPreviewRender {
                Color.clear.frame(minWidth: 50, maxWidth: .infinity)
            } else {
                Spacer().frame(minWidth: 50, maxWidth: .infinity)
            }
        case "divider":
            Rectangle()
                .fill(configManager.config.appearance.accentColor.opacity(0.4))
                .frame(width: 2, height: 15)
                .clipShape(Capsule())
        case "system-banner":
            if shouldShowSystemBanner {
                SystemBannerWidget()
            } else {
                EmptyView()
            }
        default:
            if item.id.hasPrefix("script.") {
                ScriptWidget(config: config.config)
            } else {
                Text("?\(item.id)?").foregroundColor(.red)
            }
        }
    }
}
