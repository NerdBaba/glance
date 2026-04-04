import Foundation
import AppKit

/// Manages yabai window manager configuration for external bar support.
/// Updates yabai's external_bar setting when Glance bar position changes.
final class YabaiConfigManager {
    static let shared = YabaiConfigManager()
    
    private let logger = AppLogger.shared
    private var isYabaiAvailable: Bool?
    private var yabaiPath: String?
    
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
    
    /// Updates yabai's external_bar configuration based on bar position.
    /// - Parameters:
    ///   - position: "top" or "bottom"
    ///   - barHeight: Current height of the Glance bar
    ///   - topMargin: Top margin from config (used as padding value)
    func updateExternalBarConfig(position: String, barHeight: CGFloat, topMargin: CGFloat) {
        logger.info("updateExternalBarConfig called: position=\(position), height=\(barHeight), margin=\(topMargin)", category: .app)
        
        guard checkYabaiAvailability() else {
            logger.warning("Yabai not available, skipping external_bar config update", category: .app)
            return
        }
        
        // Calculate padding values based on position
        let topPadding: Int
        let bottomPadding: Int
        
        if position == "bottom" {
            // Bar at bottom: set bottom padding to bar height + margin
            topPadding = 0
            bottomPadding = Int(barHeight + topMargin)
        } else {
            // Bar at top (default): set top padding to bar height + margin
            topPadding = Int(barHeight + topMargin)
            bottomPadding = 0
        }
        
        // Build yabai command using cached full path
        guard let yabaiPath = yabaiPath else {
            logger.error("Yabai path is nil after availability check", category: .app)
            return
        }
        
        let command = "\(yabaiPath) -m config external_bar all:\(topPadding):\(bottomPadding)"
        logger.info("Executing yabai command: \(command)", category: .app)
        
        executeYabaiCommand(command)
    }
    
    /// Resets yabai external_bar config to default (no padding).
    func resetExternalBarConfig() {
        guard checkYabaiAvailability() else { return }
        
        guard let yabaiPath = yabaiPath else { return }
        
        let command = "\(yabaiPath) -m config external_bar off"
        executeYabaiCommand(command)
    }
    
    /// Executes a shell command asynchronously with full environment.
    private func executeYabaiCommand(_ command: String) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.runCommand(command)
        }
    }
    
    /// Runs a shell command and logs the result with detailed output.
    private func runCommand(_ command: String) {
        logger.info("Running command: \(command)", category: .app)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        
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
            } else {
                logger.error("✗ Command failed (exit code \(process.terminationStatus)): \(output)", category: .app)
            }
        } catch {
            logger.error("✗ Command execution error: \(error.localizedDescription)", category: .app)
        }
    }
}
