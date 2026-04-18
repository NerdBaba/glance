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

    /// Fetch spaces and windows concurrently via async/await — bypasses output cache
    /// since yabai space/window data changes constantly and cache hits return nil.
    func getSpacesWithWindows() -> [YabaiSpace]? {
        let semaphore = DispatchSemaphore(value: 0)
        var result: [YabaiSpace]? = nil

        Task {
            async let spacesData = runner.run(arguments: ["-m", "query", "--spaces"])
            async let windowsData = runner.run(arguments: ["-m", "query", "--windows"])

            guard let spacesData = await spacesData,
                  let windowsData = await windowsData else {
                result = nil
                semaphore.signal()
                return
            }

            do {
                let spaces = try runner.decode([YabaiSpace].self, from: spacesData)
                let windows = try runner.decode([YabaiWindow].self, from: windowsData)
                result = mergeSpaces(spaces: spaces, windows: windows)
            } catch {
                result = nil
            }
            semaphore.signal()
        }

        semaphore.wait()
        return result
    }

    private func mergeSpaces(spaces: [YabaiSpace], windows: [YabaiWindow]) -> [YabaiSpace] {
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
        Task {
            _ = await runner.run(arguments: ["-m", "space", "--focus", spaceId])
            guard needWindowFocus else { return }

            try? await Task.sleep(for: .milliseconds(100))

            guard
                let requestedSpaceId = Int(spaceId),
                let spaces = getSpacesWithWindows(),
                let space = spaces.first(where: { $0.id == requestedSpaceId }),
                !space.windows.contains(where: { $0.isFocused }),
                let firstWindow = space.windows.first
            else {
                return
            }

            _ = await runner.run(arguments: [
                "-m", "window", "--focus", String(firstWindow.id),
            ])
        }
    }

    func focusWindow(windowId: String) {
        Task {
            _ = await runner.run(arguments: ["-m", "window", "--focus", windowId])
        }
    }

    private func visibleWindows(from windows: [YabaiWindow]) -> [YabaiWindow] {
        windows.filter { !($0.isHidden || $0.isFloating || $0.isSticky) }
    }
}
