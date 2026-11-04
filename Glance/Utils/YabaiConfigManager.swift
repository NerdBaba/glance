import Foundation
import AppKit

/// Manages yabai window manager configuration for external bar support.
/// Updates yabai's external_bar setting when Glance bar position changes.
final class YabaiConfigManager {
    static let shared = YabaiConfigManager()
    
    private let logger = AppLogger.shared
    private var isYabaiAvailable: Bool?
    private var yabaiPath: String?
    // Read and written only on commandQueue; failed commands are never cached.
    private var lastSuccessfulExternalBarRequest: ExternalBarRequest?

    private struct ExternalBarRequest: Equatable {
        let top: Int
        let bottom: Int
        let left: Int
        let right: Int
        let enabled: Bool
    }
    
    /// Checks if yabai is installed and accessible, caching the full path.
    /// Tries multiple methods to find yabai since Spotlight-launched apps
    /// don't inherit shell PATH.
    func checkYabaiAvailability() -> Bool {
        if let cached = isYabaiAvailable {
            return cached
        }
        
        // Try common yabai installation paths
        let possiblePaths = [
            "/usr/local/bin/yabai",      // Intel Mac Homebrew
            "/opt/homebrew/bin/yabai",   // Apple Silicon Homebrew
            "/usr/bin/yabai",            // System location
            "/usr/local/sbin/yabai",     // Alternative location
        ]
        
        // First, try direct file existence checks (works regardless of PATH)
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                yabaiPath = path
                isYabaiAvailable = true
                logger.info("Found yabai at: \(path)", category: .app)
                return true
            }
        }
        
        // Fallback: try which command (may work if PATH is set)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["yabai"]
        process.standardOutput = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                // Read the output to get the full path
                if let pipe = process.standardOutput as? Pipe,
                   let data = try? pipe.fileHandleForReading.readToEnd(),
                   let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !path.isEmpty {
                    yabaiPath = path
                    isYabaiAvailable = true
                    logger.info("Found yabai via which: \(path)", category: .app)
                    return true
                }
            }
        } catch {
            logger.warning("Error checking yabai with which: \(error.localizedDescription)", category: .app)
        }
        
        isYabaiAvailable = false
        logger.warning("Yabai not found in any standard location", category: .app)
        return false
    }
    
    /// Reserve both edges in one update; additional bottom bars must not be
    /// overwritten by a second command for the primary top bar.
    func updateExternalBarConfig(topPadding: CGFloat, bottomPadding: CGFloat, leftPadding: CGFloat = 0, rightPadding: CGFloat = 0) {
        guard checkYabaiAvailability() else { return }
        let request = ExternalBarRequest(
            top: Int(ceil(max(0, topPadding))),
            bottom: Int(ceil(max(0, bottomPadding))),
            left: Int(ceil(max(0, leftPadding))),
            right: Int(ceil(max(0, rightPadding))),
            enabled: true
        )
        enqueueExternalBarRequest(request)
    }

    /// Resets yabai external_bar config to default (no padding).
    func resetExternalBarConfig() {
        guard checkYabaiAvailability() else { return }
        enqueueExternalBarRequest(ExternalBarRequest(top: 0, bottom: 0, left: 0, right: 0, enabled: false))
    }

    private func enqueueExternalBarRequest(_ request: ExternalBarRequest) {
        guard let path = yabaiPath else { return }
        commandQueue.async { [weak self] in
            guard let self, request != self.lastSuccessfulExternalBarRequest else { return }
            self.updateSidePadding(path: path, left: request.left, right: request.right)
            let value = request.enabled ? "all:\(request.top):\(request.bottom)" : "off:0:0"
            if self.runCommand(path: path, arguments: ["-m", "config", "external_bar", value]) {
                self.lastSuccessfulExternalBarRequest = request
            }
        }
    }

    private func updateSidePadding(path: String, left: Int, right: Int) {
        for (edge, amount) in [("left", left), ("right", right)] {
            let key = "glance.yabai.reserved." + edge
            let previous = UserDefaults.standard.integer(forKey: key)
            guard previous != amount else { continue }
            let query = Process()
            query.executableURL = URL(fileURLWithPath: path)
            query.arguments = ["-m", "config", "\(edge)_padding"]
            let output = Pipe(); query.standardOutput = output; query.standardError = FileHandle.nullDevice
            do { try query.run(); query.waitUntilExit() } catch { continue }
            guard query.terminationStatus == 0,
                  let text = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8),
                  let current = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)) else { continue }
            let target = max(0, current - previous) + max(0, amount)
            let setter = Process(); setter.executableURL = URL(fileURLWithPath: path)
            setter.arguments = ["-m", "config", "\(edge)_padding", String(target)]
            setter.standardOutput = FileHandle.nullDevice; setter.standardError = FileHandle.nullDevice
            do { try setter.run(); setter.waitUntilExit() } catch { continue }
            if setter.terminationStatus == 0 { UserDefaults.standard.set(amount, forKey: key) }
        }
    }

    // Serial execution preserves configuration order during fast preset changes.
    private let commandQueue = DispatchQueue(label: "glance.yabai.config", qos: .userInitiated)

    @discardableResult
    private func runCommand(path: String, arguments: [String]) -> Bool {
        let command = ([path] + arguments).joined(separator: " ")
        logger.info("Running command: \(command)", category: .app)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments

        // Set up environment to include user's PATH
        // This is critical for Spotlight-launched apps
        let currentEnv = ProcessInfo.processInfo.environment
        var env = currentEnv
        
        // Ensure PATH includes common binary locations
        let existingPath = env["PATH"] ?? ""
        if !existingPath.contains("/usr/local/bin") {
            env["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin" + (existingPath.isEmpty ? "" : ":\(existingPath)")
        }
        
        process.environment = env
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            if process.terminationStatus == 0 {
                logger.info("✓ Command succeeded: \(command)", category: .app)
                if !output.isEmpty {
                    logger.info("  Output: \(output)", category: .app)
                }
                return true
            } else {
                logger.error("✗ Command failed (exit code \(process.terminationStatus)): \(output)", category: .app)
                return false
            }
        } catch {
            logger.error("✗ Command execution error: \(error.localizedDescription)", category: .app)
            return false
        }
    }
}
