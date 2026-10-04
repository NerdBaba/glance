import AppKit
import SwiftUI

/// Small, themeable launcher trigger for Polybar-style app-launcher modules.
struct LauncherWidget: View {
    let config: ConfigProvider

    @Environment(\.widgetFont) private var widgetFont
    @State private var isPresented = false
    @State private var searchText = ""
    @State private var applications = LaunchableApplication.installed

    private var label: String { config.config["label"]?.stringValue ?? "Apps" }
    private var symbol: String { config.config["symbol"]?.stringValue ?? "square.grid.2x2" }
    private var displayMode: String { config.config["display-mode"]?.stringValue ?? "icon" }
    private var filteredApplications: [LaunchableApplication] {
        guard !searchText.isEmpty else { return applications }
        return applications.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        Button { isPresented.toggle() } label: {
            ActionWidgetLabel(symbol: symbol, label: label, displayMode: displayMode, font: widgetFont, config: config)
        }
        .buttonStyle(.plain)
        .experimentalConfiguration(horizontalPadding: 6)
        .popover(isPresented: $isPresented, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 10) {
                TextField("Search apps", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(filteredApplications) { app in
                            Button {
                                NSWorkspace.shared.openApplication(
                                    at: app.url,
                                    configuration: NSWorkspace.OpenConfiguration(),
                                    completionHandler: { _, _ in }
                                )
                                isPresented = false
                            } label: {
                                Label {
                                    Text(app.name).lineLimit(1)
                                } icon: {
                                    Image(nsImage: app.icon).resizable().frame(width: 18, height: 18)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 3)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(width: 240, height: min(CGFloat(filteredApplications.count) * 28, 320))
            }
            .padding(12)
        }
        .help("Open app launcher")
    }
}

/// Polybar-style power-menu trigger. Destructive system actions always get a
/// second confirmation after the menu item is selected.
struct PowerWidget: View {
    let config: ConfigProvider

    @Environment(\.widgetFont) private var widgetFont
    @State private var isPresented = false
    @State private var actionToConfirm: PowerAction?

    private var label: String { config.config["label"]?.stringValue ?? "Power" }
    private var symbol: String { config.config["symbol"]?.stringValue ?? "power" }
    private var displayMode: String { config.config["display-mode"]?.stringValue ?? "icon" }

    var body: some View {
        Button { isPresented.toggle() } label: {
            ActionWidgetLabel(symbol: symbol, label: label, displayMode: displayMode, font: widgetFont, config: config)
        }
        .buttonStyle(.plain)
        .experimentalConfiguration(horizontalPadding: 6)
        .popover(isPresented: $isPresented, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 4) {
                powerButton("Sleep", symbol: "moon.zzz", action: .sleep)
                powerButton("Restart…", symbol: "arrow.clockwise", action: .restart)
                powerButton("Shut Down…", symbol: "power", action: .shutdown)
            }
            .padding(10)
            .frame(width: 170)
        }
        .confirmationDialog(
            actionToConfirm?.confirmationTitle ?? "Confirm power action",
            isPresented: Binding(
                get: { actionToConfirm != nil },
                set: { if !$0 { actionToConfirm = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let actionToConfirm {
                Button(actionToConfirm.buttonTitle, role: .destructive) {
                    perform(actionToConfirm)
                    self.actionToConfirm = nil
                }
                Button("Cancel", role: .cancel) { self.actionToConfirm = nil }
            }
        } message: {
            Text("This will affect the whole Mac.")
        }
        .help("Open power menu")
    }

    private func powerButton(_ title: String, symbol: String, action: PowerAction) -> some View {
        Button {
            isPresented = false
            actionToConfirm = action
        } label: {
            Label(title, systemImage: symbol)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
    }

    private func perform(_ action: PowerAction) {
        // Route through System Events so macOS can present its own authorization
        // and shutdown confirmation when the user chooses one of these actions.
        let event: String
        switch action {
        case .sleep: event = "sleep"
        case .restart: event = "restart"
        case .shutdown: event = "shut down"
        }
        var error: NSDictionary?
        NSAppleScript(source: "tell application \"System Events\" to \(event)")?
            .executeAndReturnError(&error)
    }
}

private enum PowerAction {
    case sleep, restart, shutdown

    var confirmationTitle: String {
        switch self {
        case .sleep: "Put this Mac to sleep?"
        case .restart: "Restart this Mac?"
        case .shutdown: "Shut down this Mac?"
        }
    }

    var buttonTitle: String {
        switch self {
        case .sleep: "Sleep"
        case .restart: "Restart"
        case .shutdown: "Shut Down"
        }
    }
}

private struct ActionWidgetLabel: View {
    let symbol: String
    let label: String
    let displayMode: String
    let font: FontConfig
    let config: ConfigProvider?

    private var showsLabel: Bool { displayMode == "label-value" || displayMode == "icon-label-value" }
    private var showsIcon: Bool { displayMode != "value" && displayMode != "label-value" && displayMode != "off" }

    var body: some View {
        if displayMode == "off" {
            EmptyView()
        } else {
            HStack(spacing: 4) {
                if showsIcon {
                    if let config {
                        PolybarIcon(config: config, glyph: config.config["glyph"]?.stringValue, systemName: symbol)
                    } else {
                        Image(systemName: symbol)
                    }
                }
                if showsLabel { Text(label) }
            }
            .font(font.toFont())
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .frame(maxHeight: .infinity)
        }
    }
}

private struct LaunchableApplication: Identifiable {
    let url: URL
    let name: String
    let icon: NSImage
    var id: String { url.path }

    static var installed: [LaunchableApplication] {
        let roots = [
            "/Applications",
            "/System/Applications",
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path,
        ]
        var seen = Set<String>()
        var apps: [LaunchableApplication] = []

        for root in roots {
            guard let enumerator = FileManager.default.enumerator(
                at: URL(fileURLWithPath: root),
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            while let url = enumerator.nextObject() as? URL {
                guard url.pathExtension == "app", seen.insert(url.path).inserted else { continue }
                enumerator.skipDescendants()
                let name = url.deletingPathExtension().lastPathComponent
                apps.append(LaunchableApplication(
                    url: url,
                    name: name,
                    icon: NSWorkspace.shared.icon(forFile: url.path)
                ))
            }
        }
        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
