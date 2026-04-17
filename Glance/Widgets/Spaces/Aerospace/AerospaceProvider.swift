import Foundation

class AerospaceSpacesProvider: SpacesProvider, SwitchableSpacesProvider {
    typealias SpaceType = AeroSpace
    private let runner: SpacesCommandRunner

    init() {
        let executablePath = ConfigManager.shared.config.aerospace.path
        runner = SpacesCommandRunner(
            toolName: "AeroSpace",
            executableURL: URL(fileURLWithPath: executablePath)
        )
    }

    func getSpacesWithWindows() -> [AeroSpace]? {
        // Use batch queries — 2 process spawns instead of 4
        guard let results = runner.decodeBatch(
            [[AeroSpace].self, [AeroWindow].self],
            arguments: [
                ["list-workspaces", "--all", "--json"],
                ["list-windows", "--all", "--json", "--format", "%{window-id} %{app-name} %{window-title} %{workspace}"],
            ]
        ) else { return nil }
        guard let spaces = results[0], let windows = results[1] else { return nil }

        // Fetch focused space and window in a second batch
        let focusedResults = runner.decodeBatch(
            [[AeroSpace].self, [AeroWindow].self],
            arguments: [
                ["list-workspaces", "--focused", "--json"],
                ["list-windows", "--focused", "--json"],
            ]
        )
        let focusedSpaceId = focusedResults?[0]?.first?.id
        let focusedWindowId = (focusedResults?[1] as? [AeroWindow])?.first?.id

        return merge(
            spaces: spaces,
            windows: windows,
            focusedSpaceId: focusedSpaceId,
            focusedWindowId: focusedWindowId
        )
    }

    func focusSpace(spaceId: String, needWindowFocus: Bool) {
        runner.run(arguments: ["workspace", spaceId])
    }

    func focusWindow(windowId: String) {
        runner.run(arguments: ["focus", "--window-id", windowId])
    }

    private func merge(
        spaces: [AeroSpace],
        windows: [AeroWindow],
        focusedSpaceId: String?,
        focusedWindowId: Int?
    ) -> [AeroSpace] {
        var indexedSpaces = Dictionary(
            uniqueKeysWithValues: spaces.map {
                ($0.id, AeroSpace(
                    workspace: $0.workspace,
                    isFocused: $0.id == focusedSpaceId
                ))
            }
        )

        for window in windows {
            var mutableWindow = window
            mutableWindow.isFocused = window.id == focusedWindowId
            guard let workspaceId = resolvedWorkspaceId(for: mutableWindow, focusedSpaceId: focusedSpaceId),
                  var space = indexedSpaces[workspaceId]
            else {
                continue
            }
            space.windows.append(mutableWindow)
            indexedSpaces[workspaceId] = space
        }

        return indexedSpaces.values
            .filter { !$0.windows.isEmpty }
            .map { space in
                var space = space
                space.windows.sort { $0.id < $1.id }
                return space
            }
            .sorted { $0.workspace.localizedStandardCompare($1.workspace) == .orderedAscending }
    }

    private func resolvedWorkspaceId(
        for window: AeroWindow,
        focusedSpaceId: String?
    ) -> String? {
        if let workspace = window.workspace, !workspace.isEmpty {
            return workspace
        }

        return focusedSpaceId
    }

    private func fetchSpaces() -> [AeroSpace]? {
        runner.decode([AeroSpace].self, arguments: [
            "list-workspaces", "--all", "--json",
        ])
    }

    private func fetchWindows() -> [AeroWindow]? {
        runner.decode([AeroWindow].self, arguments: [
            "list-windows", "--all", "--json", "--format",
            "%{window-id} %{app-name} %{window-title} %{workspace}",
        ])
    }

    private func fetchFocusedSpace() -> AeroSpace? {
        runner.decode([AeroSpace].self, arguments: [
            "list-workspaces", "--focused", "--json",
        ])?.first
    }

    private func fetchFocusedWindow() -> AeroWindow? {
        runner.decode([AeroWindow].self, arguments: [
            "list-windows", "--focused", "--json",
        ])?.first
    }
}
