import Foundation

class YabaiSpacesProvider: SpacesProvider, SwitchableSpacesProvider {
    typealias SpaceType = YabaiSpace
    private let runner: SpacesCommandRunner

    init() {
        let executablePath = ConfigManager.shared.config.yabai.path
        runner = SpacesCommandRunner(
            toolName: "yabai",
            executableURL: URL(fileURLWithPath: executablePath)
        )
    }

    private func fetchSpaces() -> [YabaiSpace]? {
        runner.decode([YabaiSpace].self, arguments: ["-m", "query", "--spaces"])
    }

    private func fetchWindows() -> [YabaiWindow]? {
        runner.decode([YabaiWindow].self, arguments: ["-m", "query", "--windows"])
    }

    func getSpacesWithWindows() -> [YabaiSpace]? {
        guard let spaces = fetchSpaces(), let windows = fetchWindows() else {
            return nil
        }

        var indexedSpaces = Dictionary(
            uniqueKeysWithValues: spaces.map { ($0.id, $0) }
        )

        for window in visibleWindows(from: windows) {
            guard var space = indexedSpaces[window.spaceId] else { continue }
            space.windows.append(window)
            indexedSpaces[window.spaceId] = space
        }

        return indexedSpaces.values
            .filter { !$0.windows.isEmpty }
            .map { space in
                var space = space
                space.windows.sort { $0.stackIndex < $1.stackIndex }
                return space
            }
            .sorted { $0.id < $1.id }
    }

    func focusSpace(spaceId: String, needWindowFocus: Bool) {
        runner.run(arguments: ["-m", "space", "--focus", spaceId])
        if !needWindowFocus { return }

        DispatchQueue.global(qos: .userInitiated).asyncAfter(
            deadline: .now() + 0.1
        ) {
            guard
                let requestedSpaceId = Int(spaceId),
                let spaces = self.getSpacesWithWindows(),
                let space = spaces.first(where: { $0.id == requestedSpaceId }),
                !space.windows.contains(where: { $0.isFocused }),
                let firstWindow = space.windows.first
            else {
                return
            }

            self.runner.run(arguments: [
                "-m", "window", "--focus", String(firstWindow.id),
            ])
        }
    }

    func focusWindow(windowId: String) {
        runner.run(arguments: ["-m", "window", "--focus", windowId])
    }

    private func visibleWindows(from windows: [YabaiWindow]) -> [YabaiWindow] {
        windows.filter { !($0.isHidden || $0.isFloating || $0.isSticky) }
    }
}
