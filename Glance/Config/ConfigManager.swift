import Foundation
import SwiftUI
import TOMLDecoder

final class ConfigManager: ObservableObject {
    static let shared = ConfigManager()

    @Published private(set) var config: Config
    @Published private(set) var initError: String?
    @Published private(set) var pywalColors: PywalColors? {
        didSet {
            if let path = configFilePath {
                parseConfigFile(at: path)
            }
        }
    }
    
    private var fileWatchSource: DispatchSourceFileSystemObject?
    private var fileDescriptor: CInt = -1
    private(set) var configFilePath: String?
    private var pywalWatchSource: DispatchSourceFileSystemObject?
    private var pywalFileDescriptor: CInt = -1
    private let logger = AppLogger.shared

    private init() {
        self.config = Config()
        self.pywalColors = nil
        self.initError = nil
        self.fileWatchSource = nil
        self.fileDescriptor = -1
        self.configFilePath = nil
        self.pywalWatchSource = nil
        self.pywalFileDescriptor = -1
        loadOrCreateConfigIfNeeded()
        loadPywalColors()
    }

    private func loadOrCreateConfigIfNeeded() {
        let homePath = FileManager.default.homeDirectoryForCurrentUser.path
        let path1 = "\(homePath)/.glance-config.toml"
        let path2 = "\(homePath)/.config/glance/config.toml"
        var chosenPath: String?

        if FileManager.default.fileExists(atPath: path1) {
            chosenPath = path1
        } else if FileManager.default.fileExists(atPath: path2) {
            chosenPath = path2
        } else {
            do {
                try createDefaultConfig(at: path1)
                chosenPath = path1
            } catch {
                initError = "Error creating default config: \(error.localizedDescription)"
                logger.error("Error creating default config: \(error.localizedDescription)", category: .config)
                return
            }
        }

        if let path = chosenPath {
            configFilePath = path
            logger.info("Using config file at \(path)", category: .config)
            parseConfigFile(at: path)
            startWatchingFile(at: path)
        }
    }

    private func parseConfigFile(at path: String) {
        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            let decoder = TOMLDecoder()
            let rootToml = try decoder.decode(RootToml.self, from: content)
            DispatchQueue.main.async {
                self.config = Config(rootToml: rootToml, pywalColors: self.pywalColors)
                self.initError = nil
            }
        } catch {
            let detailedError = detailedTOMLError(error: error, path: path)
            DispatchQueue.main.async {
                self.initError = "Config error at line \(detailedError.line): \(detailedError.message)"
            }
            logger.error("Config parse error: \(detailedError.line) - \(detailedError.message)", category: .config)
            lenientParseConfigFile(path: path)
        }
    }
    
    private func detailedTOMLError(error: Error, path: String) -> (line: Int, message: String) {
        // Try to extract info from DecodingError
        if let decodingError = error as? DecodingError {
            let codingPath = decodingError.codingPath
            if let lastKey = codingPath.last, let keyName = lastKey.stringValue, !keyName.isEmpty {
                if let content = try? String(contentsOfFile: path, encoding: .utf8) {
                    let lines = content.components(separatedBy: "\n")
                    for (index, line) in lines.enumerated() {
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        if trimmed.hasPrefix("#") { continue }
                        // Check if line defines this key
                        if trimmed.hasPrefix(keyName) {
                            if let eqIndex = trimmed.firstIndex(of: "=") {
                                let keyPart = trimmed[..<eqIndex].trimmingCharacters(in: .whitespaces)
                                if keyPart == keyName {
                                    let lineNum = index + 1
                                    let desc: String
                                    switch decodingError {
                                    case .keyNotFound:
                                        desc = "Missing required key '\(keyName)'"
                                    case .valueNotFound(let type, _):
                                        desc = "Missing value for key '\(keyName)' (expected \(type))"
                                    case .typeMismatch(let type, _):
                                        desc = "Invalid type for key '\(keyName)' (expected \(type))"
                                    @unknown default:
                                        desc = decodingError.localizedDescription
                                    }
                                    return (lineNum, desc)
                                }
                            }
                        }
                    }
                }
            }
            // If we couldn't locate the line, fall through to other heuristics
        }

        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return (0, error.localizedDescription)
        }

        let lines = content.components(separatedBy: "\n")

        // Check for common issues
        for (index, line) in lines.enumerated() {
            let lineNum = index + 1
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            // Check for duplicate sections
            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                let section = String(trimmed.dropFirst().dropLast())
                // Check if this section appears again later
                for (j, otherLine) in lines.enumerated() where j > index {
                    let otherTrimmed = otherLine.trimmingCharacters(in: .whitespaces)
                    if otherTrimmed == trimmed {
                        return (lineNum, "Duplicate section '\(section)' at line \(lineNum) (first defined at line \(lineNum))")
                    }
                }
            }

            // Check for [background] instead of [experimental.background]
            if trimmed.hasPrefix("[") && String(trimmed.dropFirst().dropLast()) == "background" {
                return (lineNum, "Use '[experimental.background]' instead of '[background]'")
            }

            // Check for [popup] without experimental
            if trimmed.hasPrefix("[") && String(trimmed.dropFirst().dropLast()) == "popup.default.time" {
                return (lineNum, "'[popup.default.time]' section - may be missing or invalid")
            }
        }

        return (0, error.localizedDescription)
    }
    
    private func lenientParseConfigFile(path: String) {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return }
        
        var partialToml = RootToml()
        
        let lines = content.components(separatedBy: "\n")
        var currentSection = ""
        var sectionLines: [String] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") && !trimmed.hasPrefix("[[") && !trimmed.hasSuffix("]]") {
                if !sectionLines.isEmpty {
                    parseSection(currentSection, lines: sectionLines, into: &partialToml)
                }
                currentSection = String(trimmed.dropFirst().dropLast())
                sectionLines = []
            } else if !trimmed.isEmpty && !trimmed.hasPrefix("#") {
                sectionLines.append(line)
            }
        }
        
        if !sectionLines.isEmpty {
            parseSection(currentSection, lines: sectionLines, into: &partialToml)
        }
        
        DispatchQueue.main.async {
            self.config = Config(rootToml: partialToml, pywalColors: self.pywalColors)
        }
        logger.warning("Used lenient config parsing due to errors", category: .config)
    }
    
    private func parseSection(_ section: String, lines: [String], into root: inout RootToml) {
        let sectionContent = lines.joined(separator: "\n")
        
        if section == "widgets" {
            if let widgets = try? TOMLDecoder().decode(WidgetsSection.self, from: sectionContent) {
                root.widgets = widgets
            }
        } else if section == "appearance" {
            if let appearance = try? TOMLDecoder().decode(AppearanceOverrides.self, from: sectionContent) {
                root.appearanceOverrides = appearance
            }
        } else if section == "experimental" {
            if let experimental = try? TOMLDecoder().decode(ExperimentalConfig.self, from: sectionContent) {
                root.experimental = experimental
            }
        } else if section.hasPrefix("widgets.default.") {
            let widgetKey = String(section.dropFirst("widgets.".count))
            var widgetConfig: ConfigData = [:]
            for line in lines {
                if let eqIndex = line.firstIndex(of: "=") {
                    let k = String(line[..<eqIndex]).trimmingCharacters(in: .whitespaces)
                    let v = String(line[line.index(after: eqIndex)...]).trimmingCharacters(in: .whitespaces)
                    if v.hasPrefix("\"") && v.hasSuffix("\"") {
                        widgetConfig[k] = .string(String(v.dropFirst().dropLast()))
                    } else if v == "true" {
                        widgetConfig[k] = .bool(true)
                    } else if v == "false" {
                        widgetConfig[k] = .bool(false)
                    } else if let num = Int(v) {
                        widgetConfig[k] = .int(num)
                    } else {
                        widgetConfig[k] = .string(v)
                    }
                }
            }
            let existing = root.widgets ?? WidgetsSection(displayed: [], others: [:])
            var newOthers = existing.others
            newOthers[widgetKey] = widgetConfig
            root.widgets = WidgetsSection(displayed: existing.displayed, others: newOthers)
        }
    }

    private func createDefaultConfig(at path: String) throws {
        let defaultTOML = """
            # If you installed yabai or aerospace without using Homebrew,
            # manually set the path to the binary. For example:
            #
            # yabai.path = "/run/current-system/sw/bin/yabai"
            # aerospace.path = ...

            theme = "system" # system, light, dark

            # Use Pywal colors dynamically (overrides preset colors)
            # use-pywal = false

            # Visual preset (overrides style). Available:
            #   liquid-glass, frosted, flat-dark, minimal-strip, system-native, neon
            # preset = "liquid-glass"

            # Override individual appearance parameters (optional):
            # [appearance]
            # roundness = 50       # 0 = square, 50 = capsule
            # border-width = 1.0
            # border-opacity = 0.4
            # fill-opacity = 0.04
            # glow-opacity = 0.05
            # shadow-opacity = 0.08
            # shadow-radius = 4.0

            [widgets]
            displayed = [ # widgets on menu bar
                "default.spaces",
                "spacer",
                "default.network",
                "default.battery",
                "divider",
                # { "default.time" = { time-zone = "America/Los_Angeles", format = "E d, hh:mm" } },
                "default.time"
            ]

            [widgets.default.spaces]
            space.show-key = true        # show space number (or character, if you use AeroSpace)
            window.show-title = true
            window.title.max-length = 50

            [widgets.default.battery]
            show-percentage = true
            warning-level = 30
            critical-level = 10

            # [widgets.default.volume]
            # show-percentage = false
            # scroll-step = 3

            # [widgets.default.brightness]
            # show-percentage = false
            # scroll-step = 3

            [widgets.default.time]
            format = "E d, J:mm"
            calendar.format = "J:mm"

            calendar.show-events = true
            # calendar.allow-list = ["Home", "Personal"] # show only these calendars
            # calendar.deny-list = ["Work", "Boss"] # show all calendars except these

            # Weather widget options:
            # [widgets.default.weather]
            # provider = "met-no" # met-no (default) or open-meteo
            # use-ip-fallback = true
            #
            # [widgets.default.weather.location]
            # latitude = 55.7558
            # longitude = 37.6173
            # name = "Moscow"

            [popup.default.time]
            view-variant = "box"
            
            [background]
            enabled = true
            """
        try defaultTOML.write(toFile: path, atomically: true, encoding: .utf8)
    }

    private func startWatchingFile(at path: String) {
        stopWatchingFile()
        fileDescriptor = open(path, O_EVTONLY)
        if fileDescriptor == -1 {
            let message = String(cString: strerror(errno))
            logger.error("Failed to watch config file at \(path): \(message)", category: .config)
            return
        }
        fileWatchSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename, .revoke],
            queue: DispatchQueue.global())
        fileWatchSource?.setEventHandler { [weak self] in
            guard let self = self, let path = self.configFilePath else {
                return
            }
            let data = self.fileWatchSource?.data ?? []
            // File was replaced (vim, sed -i, atomic write) — re-establish watcher
            if data.contains(.delete) || data.contains(.rename) || data.contains(.revoke) {
                self.stopWatchingFile()
                // Brief delay for the new file to settle
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
                    self.parseConfigFile(at: path)
                    self.startWatchingFile(at: path)
                }
                return
            }
            self.parseConfigFile(at: path)
        }
        fileWatchSource?.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd != -1 {
                close(fd)
                self?.fileDescriptor = -1
            }
        }
        fileWatchSource?.resume()
    }

    private func stopWatchingFile() {
        fileWatchSource?.cancel()
        fileWatchSource = nil
    }

    private func loadPywalColors() {
        pywalColors = PywalColors()
        startWatchingPywal()
    }

    private func startWatchingPywal() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let path = homeDir.appendingPathComponent(".cache/wal/colors").path
        if !FileManager.default.fileExists(atPath: path) { return }

        stopWatchingPywal()
        pywalFileDescriptor = open(path, O_EVTONLY)
        if pywalFileDescriptor == -1 {
            let message = String(cString: strerror(errno))
            logger.error("Failed to watch pywal file at \(path): \(message)", category: .config)
            return
        }
        pywalWatchSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: pywalFileDescriptor,
            eventMask: [.write, .delete, .rename, .revoke],
            queue: DispatchQueue.global())
        pywalWatchSource?.setEventHandler { [weak self] in
            guard let self = self else { return }
            let data = self.pywalWatchSource?.data ?? []
            if data.contains(.delete) || data.contains(.rename) || data.contains(.revoke) {
                self.stopWatchingPywal()
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
                    self.loadPywalColors()
                }
                return
            }
            self.pywalColors = PywalColors()
        }
        pywalWatchSource?.setCancelHandler { [weak self] in
            if let fd = self?.pywalFileDescriptor, fd != -1 {
                close(fd)
                self?.pywalFileDescriptor = -1
            }
        }
        pywalWatchSource?.resume()
    }

    private func stopWatchingPywal() {
        pywalWatchSource?.cancel()
        pywalWatchSource = nil
    }

    func updateConfigValue(key: String, newValue: String) {
        print("ConfigManager.updateConfigValue called: \(key) = \(newValue)")
        guard let path = configFilePath else {
            logger.warning("Config file path is not set while updating \(key)", category: .config)
            return
        }
        do {
            let currentText = try String(contentsOfFile: path, encoding: .utf8)
            let updatedText = updatedTOMLString(
                original: currentText, key: key, newValue: newValue)
            try updatedText.write(
                toFile: path, atomically: false, encoding: .utf8)
            // File watcher will trigger parseConfigFile automatically
        } catch {
            logger.error("Error updating config key \(key): \(error.localizedDescription)", category: .config)
        }
    }

    /// Batch-update multiple config keys in a single file write.
    func updateConfigValues(pairs: [(key: String, value: String)]) {
        guard let path = configFilePath else {
            logger.warning("Config file path is not set while batch updating config", category: .config)
            return
        }
        do {
            var text = try String(contentsOfFile: path, encoding: .utf8)
            for (key, value) in pairs {
                text = updatedTOMLString(original: text, key: key, newValue: value)
            }
            try text.write(toFile: path, atomically: false, encoding: .utf8)
        } catch {
            let updatedKeys = pairs.map(\.key).joined(separator: ", ")
            logger.error("Error batch-updating config keys [\(updatedKeys)]: \(error.localizedDescription)", category: .config)
        }
    }

    func removeConfigValue(key: String) {
        removeConfigValues(keys: [key])
    }

    func removeConfigValues(keys: [String]) {
        guard let path = configFilePath else {
            logger.warning("Config file path is not set while removing config", category: .config)
            return
        }

        do {
            var text = try String(contentsOfFile: path, encoding: .utf8)
            for key in keys {
                text = removedConfigValue(from: text, key: key)
            }
            try text.write(toFile: path, atomically: false, encoding: .utf8)
        } catch {
            let removedKeys = keys.joined(separator: ", ")
            logger.error("Error removing config keys [\(removedKeys)]: \(error.localizedDescription)", category: .config)
        }
    }

    /// Formats a value for TOML: numbers and booleans are bare, arrays are bare, strings get quotes.
    private func tomlFormatted(_ value: String) -> String {
        // Booleans
        if value == "true" || value == "false" { return value }
        // Arrays
        if value.hasPrefix("[") && value.hasSuffix("]") { return value }
        // Integer
        if Int(value) != nil { return value }
        // Float
        if Double(value) != nil { return value }
        // String — wrap in quotes
        return "\"\(value)\""
    }

    /// Count unbalanced open brackets in a string (for multi-line array detection).
    private func unclosedBracketDepth(_ s: String) -> Int {
        var depth = 0
        for ch in s {
            if ch == "[" { depth += 1 }
            else if ch == "]" { depth -= 1 }
        }
        return depth
    }

    private func updatedTOMLString(
        original: String, key: String, newValue: String
    ) -> String {
        let formatted = tomlFormatted(newValue)

        if key.contains(".") {
            let components = key.split(separator: ".").map(String.init)
            guard components.count >= 2 else {
                return original
            }

            let tablePath = components.dropLast().joined(separator: ".")
            let actualKey = components.last!

            let tableHeader = "[\(tablePath)]"
            let lines = original.components(separatedBy: "\n")
            var newLines: [String] = []
            var insideTargetTable = false
            var updatedKey = false
            var foundTable = false
            var skipBracketDepth = 0

            for line in lines {
                // Skip continuation lines of a replaced multi-line value
                if skipBracketDepth > 0 {
                    skipBracketDepth += unclosedBracketDepth(line)
                    continue
                }

                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("[") && !trimmed.hasPrefix("[[") && trimmed.hasSuffix("]") && !trimmed.hasSuffix("]]") {
                    if insideTargetTable && !updatedKey {
                        newLines.append("\(actualKey) = \(formatted)")
                        updatedKey = true
                    }
                    if trimmed == tableHeader {
                        foundTable = true
                        insideTargetTable = true
                    } else {
                        insideTargetTable = false
                    }
                    newLines.append(line)
                } else {
                    if insideTargetTable && !updatedKey {
                        let pattern =
                            "^\(NSRegularExpression.escapedPattern(for: actualKey))\\s*="
                        if line.range(of: pattern, options: .regularExpression)
                            != nil
                        {
                            newLines.append("\(actualKey) = \(formatted)")
                            updatedKey = true
                            // Check if original line had unclosed brackets (multi-line value)
                            let depth = unclosedBracketDepth(line)
                            if depth > 0 { skipBracketDepth = depth }
                            continue
                        }
                    }
                    newLines.append(line)
                }
            }

            if foundTable && insideTargetTable && !updatedKey {
                newLines.append("\(actualKey) = \(formatted)")
            }

            if !foundTable {
                newLines.append("")
                newLines.append("[\(tablePath)]")
                newLines.append("\(actualKey) = \(formatted)")
            }
            return newLines.joined(separator: "\n")
        } else {
            let lines = original.components(separatedBy: "\n")
            var newLines: [String] = []
            var updatedAtLeastOnce = false
            var skipBracketDepth = 0

            for line in lines {
                // Skip continuation lines of a replaced multi-line value
                if skipBracketDepth > 0 {
                    skipBracketDepth += unclosedBracketDepth(line)
                    continue
                }

                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if !trimmed.hasPrefix("#") {
                    let pattern =
                        "^\(NSRegularExpression.escapedPattern(for: key))\\s*="
                    if line.range(of: pattern, options: .regularExpression)
                        != nil
                    {
                        newLines.append("\(key) = \(formatted)")
                        updatedAtLeastOnce = true
                        let depth = unclosedBracketDepth(line)
                        if depth > 0 { skipBracketDepth = depth }
                        continue
                    }
                }
                newLines.append(line)
            }
            if !updatedAtLeastOnce {
                // Insert before the first [section] header so the key stays top-level
                var inserted = false
                var result: [String] = []
                for line in newLines {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if !inserted && trimmed.hasPrefix("[") && !trimmed.hasPrefix("[[") && trimmed.hasSuffix("]") && !trimmed.hasSuffix("]]") {
                        result.append("\(key) = \(formatted)")
                        result.append("")
                        inserted = true
                    }
                    result.append(line)
                }
                if !inserted {
                    result.append("\(key) = \(formatted)")
                }
                return result.joined(separator: "\n")
            }
            return newLines.joined(separator: "\n")
        }
    }

    private func removedConfigValue(from original: String, key: String) -> String {
        let lines = original.components(separatedBy: "\n")
        var newLines: [String] = []
        var skipBracketDepth = 0

        if key.contains(".") {
            let components = key.split(separator: ".").map(String.init)
            guard components.count >= 2 else { return original }

            let tablePath = components.dropLast().joined(separator: ".")
            let actualKey = components.last!
            let tableHeader = "[\(tablePath)]"
            let keyPattern = "^\(NSRegularExpression.escapedPattern(for: actualKey))\\s*="

            var insideTargetTable = false

            for line in lines {
                if skipBracketDepth > 0 {
                    skipBracketDepth += unclosedBracketDepth(line)
                    continue
                }

                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("[") && !trimmed.hasPrefix("[[") && trimmed.hasSuffix("]") && !trimmed.hasSuffix("]]") {
                    insideTargetTable = trimmed == tableHeader
                    newLines.append(line)
                    continue
                }

                if insideTargetTable && line.range(of: keyPattern, options: .regularExpression) != nil {
                    let depth = unclosedBracketDepth(line)
                    if depth > 0 { skipBracketDepth = depth }
                    continue
                }

                newLines.append(line)
            }
        } else {
            let keyPattern = "^\(NSRegularExpression.escapedPattern(for: key))\\s*="

            for line in lines {
                if skipBracketDepth > 0 {
                    skipBracketDepth += unclosedBracketDepth(line)
                    continue
                }

                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if !trimmed.hasPrefix("#") && line.range(of: keyPattern, options: .regularExpression) != nil {
                    let depth = unclosedBracketDepth(line)
                    if depth > 0 { skipBracketDepth = depth }
                    continue
                }

                newLines.append(line)
            }
        }

        return newLines.joined(separator: "\n")
    }

    func globalWidgetConfig(for widgetId: String) -> ConfigData {
        config.rootToml.widgets?.config(for: widgetId) ?? [:]
    }

    func resolvedWidgetConfig(for item: TomlWidgetItem) -> ConfigData {
        let global = globalWidgetConfig(for: item.id)
        if item.inlineParams.isEmpty {
            return global
        }
        var merged = global
        for (key, value) in item.inlineParams {
            merged[key] = value
        }
        return merged
    }
}
