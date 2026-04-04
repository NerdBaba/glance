import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var isEnabled = true
    var savedCorners: [String: Int] = [:]

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "HC"

        updateMenu()
    }

    @objc func toggleHotCorners() {
        if isEnabled {
            savedCorners = readHotCorners()
            setHotCorners(all: 0)
            isEnabled = false
        } else {
            setHotCorners(corners: savedCorners)
            savedCorners = [:]
            isEnabled = true
        }
        runCommand("killall Dock")
        updateMenu()
    }

    func updateMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: isEnabled ? "Disable Hot Corners" : "Enable Hot Corners", action: #selector(toggleHotCorners), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
    }

    func readHotCorners() -> [String: Int] {
        let corners = ["wvous-tl-corner", "wvous-tr-corner", "wvous-bl-corner", "wvous-br-corner"]
        var dict = [String: Int]()
        for corner in corners {
            if let value = readDefaults(corner) {
                dict[corner] = value
            }
        }
        return dict
    }

    func readDefaults(_ key: String) -> Int? {
        let output = runCommand("defaults read com.apple.dock \(key)")
        return Int(output.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func setHotCorners(all value: Int) {
        let corners = ["wvous-tl-corner", "wvous-tr-corner", "wvous-bl-corner", "wvous-br-corner"]
        for corner in corners {
            runCommand("defaults write com.apple.dock \(corner) -int \(value)")
        }
    }

    func setHotCorners(corners: [String: Int]) {
        for (key, value) in corners {
            runCommand("defaults write com.apple.dock \(key) -int \(value)")
        }
    }

    func runCommand(_ command: String) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        let pipe = Pipe()
        process.standardOutput = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }
}