import SwiftUI

struct MenuBarView: View {
    @ObservedObject var configManager = ConfigManager.shared
    @Environment(\.barReferenceScale) private var referenceScale

    private var shouldShowSystemBanner: Bool {
        ProcessInfo.processInfo.environment["GLANCE_PREVIEW_BAR_PATH"] == nil
            && !CommandLine.arguments.contains("--export-bar")
            && !CommandLine.arguments.contains("--preview-panel")
            && !CommandLine.arguments.contains("--benchmark-panel")
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
            if fg.isVertical {
                verticalBar(items: items, appearance: appearance, fg: fg)
            } else { switch formation {
            case .full:
                fullBar(items: items, appearance: appearance, fg: fg)
            case .floating:
                floatingBar(items: items, appearance: appearance, fg: fg)
            case .islands:
                islandsBar(items: items, appearance: appearance, fg: fg)
            case .pills:
                pillsBar(items: items, appearance: appearance, fg: fg)
            } }
        }
        .foregroundStyle(appearance.foregroundColor)
        .frame(height: fg.isVertical ? nil : max(fg.resolveHeight(), 1.0))
        .frame(maxWidth: .infinity)
        .padding(.horizontal, fg.isVertical ? 0 : fg.margin * referenceScale)
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

    @ViewBuilder
    private func verticalBar(items: [TomlWidgetItem], appearance: AppearanceConfig, fg: ForegroundConfig) -> some View {
        VStack(spacing: fg.spacing) {
            ForEach(Array(capsuleClusters(items).enumerated()), id: \.offset) { _, cluster in
                if let first = cluster.first, clusterName(first) != nil {
                    let values = configManager.resolvedWidgetConfig(for: first)
                    let color = PolybarModuleStyle.color(values["capsule-background"]?.stringValue, palette: configManager.config.pywalColors?.colors ?? [])
                    VStack(spacing: bounded(values, "capsule-spacing", fallback: fg.spacing, maximum: 40)) {
                        ForEach(Array(cluster.enumerated()), id: \.offset) { _, item in
                            verticalItem(item, appearance: appearance)
                        }
                    }
                    .padding(.vertical, bounded(values, "capsule-vertical-padding", fallback: 8, maximum: 40))
                    .frame(width: bounded(values, "capsule-width", fallback: fg.resolveHeight(), maximum: 160))
                    .background((color ?? .clear).opacity(min(max(values["capsule-background-opacity"]?.doubleValue ?? 1, 0), 1)))
                    .environment(\.glanceCapsuleBackground, color?.opacity(min(max(values["capsule-background-opacity"]?.doubleValue ?? 1, 0), 1)))
                    .clipShape(RoundedRectangle(cornerRadius: bounded(values, "capsule-radius", fallback: 14, maximum: 50)))
                } else if let item = cluster.first {
                    verticalItem(item, appearance: appearance)
                }
            }
        }
        .padding(.vertical, fg.horizontalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(appearance.widgetBackgroundColor.opacity(appearance.fillOpacity))
        .clipShape(RoundedRectangle(cornerRadius: appearance.roundness / 100 * min(fg.resolveHeight(), 40) / 2))
    }

    @ViewBuilder
    private func verticalItem(_ item: TomlWidgetItem, appearance: AppearanceConfig) -> some View {
        if item.id == "spacer" { Spacer(minLength: 0) }
        else if item.id == "divider" { Rectangle().fill(appearance.accentColor.opacity(0.4)).frame(height: 1) }
        else {
            let values = configManager.resolvedWidgetConfig(for: item)
            moduleView(for: item, height: values["native-orientation"]?.stringValue == "vertical" ? nil : (values["native-line-limit"]?.intValue ?? 1) > 1 ? 40 : 28)
                .fixedSize(horizontal: false, vertical: true)
        }
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
        .frame(width: fg.floatingWidth > 0 ? fg.floatingWidth * referenceScale : nil)
        .frame(maxWidth: fg.floatingWidth > 0 ? nil : .infinity)
        .frame(height: capsuleHeight(fg))
        .widgetStyle(appearance, heightOverride: capsuleHeight(fg), showBackground: showBg)
        .background(alignment: .top) {
            if fg.floatingFlatTop && showBg {
                Rectangle().fill(appearance.widgetBackgroundColor).frame(height: capsuleHeight(fg) / 2)
            }
        }

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
            } else if spacerCount == 2 && nonSpacerGroups.count == 3 && !fg.scaleContent {
                PolybarAlignedGroups(gap: fg.gap, centerOffset: fg.centerGroupOffset * referenceScale) {
                    pillCapsule(nonSpacerGroups[0], height: height, appearance: appearance, fg: fg,
                                minWidth: fg.leftGroupWidth * referenceScale, alignment: .leading)
                    pillCapsule(nonSpacerGroups[1], height: height, appearance: appearance, fg: fg,
                                minWidth: fg.centerGroupWidth * referenceScale, alignment: .center)
                    pillCapsule(nonSpacerGroups[2], height: height, appearance: appearance, fg: fg,
                                minWidth: fg.rightGroupWidth * referenceScale, alignment: .trailing)
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
        .frame(minWidth: minWidth, maxWidth: fixedWidth && fg.scaleContent && minWidth > 0 ? minWidth : nil, alignment: hasSegmentBackground ? .leading : alignment)
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
        max(fg.resolveHeight() - fg.floatingInset, 1)
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
        ForEach(Array(capsuleClusters(items).enumerated()), id: \.offset) { _, cluster in
            if let first = cluster.first, clusterName(first) != nil {
                let values = configManager.resolvedWidgetConfig(for: first)
                let palette = configManager.config.pywalColors?.colors ?? []
                HStack(spacing: bounded(values, "capsule-spacing", fallback: 0, maximum: 40)) {
                    ForEach(Array(cluster.enumerated()), id: \.offset) { _, item in moduleView(for: item) }
                }
                .padding(.horizontal, bounded(values, "capsule-padding", fallback: 4, maximum: 40))
                .frame(minWidth: bounded(values, "capsule-min-width", fallback: 0, maximum: 2048),
                       alignment: values["capsule-alignment"]?.stringValue == "right" ? .trailing : .center)
                .frame(height: bounded(values, "capsule-height", fallback: 28, maximum: 100))
                .background(PolybarModuleStyle.color(values["capsule-background"]?.stringValue, palette: palette) ?? .clear)
                .environment(\.glanceCapsuleBackground, PolybarModuleStyle.color(values["capsule-background"]?.stringValue, palette: palette))
                .clipShape(RoundedRectangle(cornerRadius: bounded(values, "capsule-radius", fallback: 14, maximum: 50)))
            } else if let item = cluster.first {
                moduleView(for: item)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
    }

    // A capsule groups consecutive modules without changing their individual
    // providers, click actions or settings. Unconfigured presets keep one item
    // per cluster and retain their original layout.
    private func clusterName(_ item: TomlWidgetItem) -> String? {
        guard let name = configManager.resolvedWidgetConfig(for: item)["capsule-group"]?.stringValue,
              !name.isEmpty else { return nil }
        return name
    }

    private func capsuleClusters(_ items: [TomlWidgetItem]) -> [[TomlWidgetItem]] {
        var result: [[TomlWidgetItem]] = []
        for item in items {
            if let name = clusterName(item), let previous = result.last?.last,
               clusterName(previous) == name {
                result[result.count - 1].append(item)
            } else { result.append([item]) }
        }
        return result
    }

    private func bounded(_ values: ConfigData, _ key: String, fallback: Double, maximum: Double) -> CGFloat {
        CGFloat(min(max(values[key]?.doubleValue ?? fallback, 0), maximum))
    }

    @ViewBuilder
    private func widgetContent(items: [TomlWidgetItem], fg: ForegroundConfig) -> some View {
        let sections = splitBySpacer(items)
        let hasBanner = items.contains(where: { $0.id == "system-banner" })

        if sections.count == 3 && !fg.scaleContent {
            PolybarAlignedGroups(gap: 8, centerOffset: fg.centerGroupOffset) {
                HStack(spacing: groupSpacing(sections[0], fallback: fg.spacing)) { widgetRow(sections[0]) }
                HStack(spacing: groupSpacing(sections[1], fallback: fg.spacing)) { widgetRow(sections[1]) }
                HStack(spacing: groupSpacing(sections[2], fallback: fg.spacing)) {
                    widgetRow(sections[2])
                    if shouldShowSystemBanner && !hasBanner {
                        SystemBannerWidget(withLeftPadding: true)
                    }
                }
            }
        } else if sections.count == 3 {
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

    private func groupSpacing(_ items: [TomlWidgetItem], fallback: CGFloat) -> CGFloat {
        guard let first = items.first, let spacing = configManager.resolvedWidgetConfig(for: first)["group-spacing"]?.doubleValue else { return fallback }
        return CGFloat(min(max(spacing, -24), 80))
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
    func moduleView(for item: TomlWidgetItem, height: CGFloat? = nil) -> some View {
        let style = PolybarModuleStyle.resolve(item: item, configManager: configManager)
        let appearance = configManager.config.appearance
        let widget = buildView(for: item)
            .tracking(min(max(configManager.resolvedWidgetConfig(for: item)["format-tracking"]?.doubleValue ?? 0, -3), 6))
            .offset(y: min(max(configManager.resolvedWidgetConfig(for: item)["format-offset-y"]?.doubleValue ?? 0, -12), 12))
            .environment(\.usesPolybarModuleLayout, style.usesModuleLayout)
            .environment(\.widgetFont, style.font ?? (appearance.useSingleFont ? appearance.barFont : appearance.widgetFont))
        if style.hasSegmentStyle {
            if let height = style.height ?? height {
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
            if item.id.hasPrefix("script."), config.config["native-source"] != nil {
                PolybarNativeWidget(config: config.config, configManager: configManager)
            } else if item.id.hasPrefix("script.") {
                ScriptWidget(config: config.config)
                    .id(PolybarScriptOptions(values: config.config).runtimeIdentity)
            } else {
                Text("?\(item.id)?").foregroundColor(.red)
            }
        }
    }
}

/// Preserve true centering when it fits; move the center group only far enough
/// to avoid the edge groups. Measuring during layout also works in image exports
/// without an asynchronous geometry preference pass.
private struct PolybarAlignedGroups: Layout {
    let gap: CGFloat
    let centerOffset: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(ProposedViewSize(width: nil, height: proposal.height)) }
        return CGSize(width: proposal.width ?? sizes.reduce(0) { $0 + $1.width },
                      height: proposal.height ?? sizes.map(\.height).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 3 else { return }
        // Flexible module backgrounds and button labels need the actual bar height.
        // An unspecified height measures them at their compressed intrinsic size.
        let sizes = subviews.map { $0.sizeThatFits(ProposedViewSize(width: nil, height: bounds.height)) }
        let leftEdge = bounds.minX + sizes[0].width + (sizes[0].width > 0 ? gap : 0)
        let rightEdge = bounds.maxX - sizes[2].width - (sizes[2].width > 0 ? gap : 0)
        let centerProposal = ProposedViewSize(width: max(0, min(sizes[1].width, rightEdge - leftEdge)), height: bounds.height)
        let centerSize = subviews[1].sizeThatFits(centerProposal)
        let minimumCenter = leftEdge + centerSize.width / 2
        let maximumCenter = rightEdge - centerSize.width / 2
        let center = minimumCenter <= maximumCenter
            ? min(max(bounds.midX + centerOffset, minimumCenter), maximumCenter)
            : (minimumCenter + maximumCenter) / 2
        subviews[0].place(at: CGPoint(x: bounds.minX, y: bounds.midY), anchor: .leading,
                          proposal: ProposedViewSize(width: sizes[0].width, height: bounds.height))
        subviews[1].place(at: CGPoint(x: center, y: bounds.midY), anchor: .center,
                          proposal: centerProposal)
        subviews[2].place(at: CGPoint(x: bounds.maxX, y: bounds.midY), anchor: .trailing,
                          proposal: ProposedViewSize(width: sizes[2].width, height: bounds.height))
    }
}

private struct GlanceCapsuleBackgroundKey: EnvironmentKey {
    static let defaultValue: Color? = nil
}
extension EnvironmentValues {
    var glanceCapsuleBackground: Color? {
        get { self[GlanceCapsuleBackgroundKey.self] }
        set { self[GlanceCapsuleBackgroundKey.self] = newValue }
    }
}
