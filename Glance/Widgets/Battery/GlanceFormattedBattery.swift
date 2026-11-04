import IOKit.ps
import SwiftUI

struct GlanceFormattedBattery: View {
    let config: ConfigData
    let manager: ConfigManager
    @ObservedObject private var battery = BatteryManager.shared
    @Environment(\.isBarPreviewRendering) private var preview
    @State private var presented = false

    private var hasBattery: Bool {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return false }
        return !sources.isEmpty
    }

    var body: some View {
        let percentage = preview ? (ProcessInfo.processInfo.environment["GLANCE_PREVIEW_BATTERY_PERCENTAGE"].flatMap(Int.init) ?? 91) : battery.batteryLevel
        PolybarFormattedContent(config: config, manager: manager, value: Double(percentage), tokens: [
            "percentage": preview || hasBattery ? String(percentage) : "—",
            "charging": battery.isCharging ? "Charging" : "",
            "remaining": battery.timeRemaining.map(BatteryManager.formatTimeRemaining) ?? "—"
        ], action: { _ in if !preview { presented.toggle() } })
        .popover(isPresented: $presented) { BatteryPopup(configProvider: ConfigProvider(config: config)) }
    }
}
