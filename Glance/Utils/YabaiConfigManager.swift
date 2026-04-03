import Foundation
import AppKit

/// Manages yabai window manager configuration for external bar support.
/// Updates yabai's external_bar setting when Glance bar position changes.
final class YabaiConfigManager {
    static let shared = YabaiConfigManager()
    
    private let logger = AppLogger.shared
    private var isYabaiAvailable: Bool?
    
    /// Checks if yabai is installed and accessible.
    func checkYabaiAvailability() -> Bool {
        if let cached = isYabaiAvailable {
            return cached
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["yabai"]
        
        do {
            try process.run()
            process.waitUntilExit()
            isYabaiAvailable = (process.terminationStatus == 0)
            return isYabaiAvailable!
        } catch {
            isYabaiAvailable = false
            return false
        }
    }
    
    /// Updates yabai's external_bar configuration based on bar position.
    /// - Parameters:
    ///   - position: "top" or "bottom"
    ///   - barHeight: Current height of the Glance bar
    ///   - topMargin: Top margin from config (used as padding value)
    func updateExternalBarConfig(position: String, barHeight: CGFloat, topMargin: CGFloat) {
        guard checkYabaiAvailability() else {
            logger.info("Yabai not available, skipping external_bar config update", category: .app)
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
        
        // Build yabai command: external_bar all:<top>:<bottom>
        let command = "yabai -m config external_bar all:\(topPadding):\(bottomPadding)"
        
        executeYabaiCommand(command)
    }
    
    /// Resets yabai external_bar config to default (no padding).
    func resetExternalBarConfig() {
        guard checkYabaiAvailability() else { return }
        
        let command = "yabai -m config external_bar off"
        executeYabaiCommand(command)
    }
    
    /// Executes a shell command asynchronously.
    private func executeYabaiCommand(_ command: String) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.runCommand(command)
        }
    }
    
    /// Runs a shell command and logs the result.
    private func runCommand(_ command: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            if process.terminationStatus == 0 {
                logger.info("Yabai command executed: \(command)", category: .app)
            } else {
                logger.warning("Yabai command failed (\(process.terminationStatus)): \(output)", category: .app)
            }
        } catch {
            logger.error("Yabai command error: \(error.localizedDescription)", category: .app)
        }
    }
}
