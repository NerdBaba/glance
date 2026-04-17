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
        let semaphore = DispatchSemaphore(value: 0)
        var result: [AeroSpace]? = nil

        Task {
            // Two concurrent batch queries — replaces 4 sequential spawns
            async let batch1 = runner.decodeTwo(
                [AeroSpace].self, argsA: ["list-workspaces", "--all", "--json"],
                [AeroWindow].self, argsB: ["list-windows", "--all", "--json", "--format", "%{window-id} %{app-name} %{window-title} %{workspace}"]
            )
            async let batch2 = runner.decodeTwo(
                [AeroSpace].self, argsA: ["list-workspaces", "--focused", "--json"],
                [AeroWindow].self, argsB: ["list-windows", "--focused", "--json"]
            )

            let (allResult, focusedResult) = await (batch1, batch2)
            let spaces = allResult.0
            let windows = allResult.1
            let focusedSpaceId = focusedResult.0?.first?.id
            let focusedWindowId = (focusedResult.1 as? [AeroWindow])?.first?.id

            guard let spaces = spaces, let windows = windows else {
                result = nil
                semaphore.signal()
                return
            }

            result = merge(
                spaces: spaces,
                windows: windows,
                focusedSpaceId: focusedSpaceId,
                focusedWindowId: focusedWindowId
            )
            semaphore.signal()
        }

        semaphore.wait()
        return result
    }

    func focusSpace(spaceId: String, needWindowFocus: Bool) {
        Task {
            _ = await runner.run(arguments: ["workspace", spaceId])
        }
    }

    func focusWindow(windowId: String) {
        Task {
            _ = await runner.run(arguments: ["focus", "--window-id", windowId])
        }
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
}
