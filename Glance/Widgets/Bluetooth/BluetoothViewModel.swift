import AppKit
import Foundation
import IOBluetooth

struct BluetoothDeviceInfo: Identifiable, Equatable {
    let id: String
    let name: String
    let isConnected: Bool
    let batteryLevel: Int?  // 0-100, nil if unknown
    let icon: String
}

final class BluetoothViewModel: ObservableObject {
    static let shared = BluetoothViewModel()

    @Published var devices: [BluetoothDeviceInfo] = []
    @Published var connectedCount: Int = 0
    @Published var isPoweredOn = false

    private var timer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private let samplingQueue = DispatchQueue(label: "BluetoothSampling", qos: .utility)

    private struct Snapshot: Equatable {
        let devices: [BluetoothDeviceInfo]
        let connectedCount: Int
        let isPoweredOn: Bool
    }

    init() {
        update()
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.update()
        }
        timer?.tolerance = 2
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.update()
        }
    }

    deinit {
        timer?.invalidate()
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
    }

    private func update() {
        samplingQueue.async { [weak self] in
            guard let self else { return }
            let powered = IOBluetoothHostController.default()?.powerState.rawValue == 1
            let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []
            let connected = paired.filter { $0.isConnected() }
            let batteryLevels = connected.isEmpty ? [:] : Self.batteryLevelsByAddress()
            let infos = connected.map { device -> BluetoothDeviceInfo in
                let name = device.name ?? "Unknown"
                let address = device.addressString
                let battery = address.flatMap { batteryLevels[$0.lowercased()] }
                let icon = Self.iconName(for: device)
                return BluetoothDeviceInfo(
                    id: address ?? name,
                    name: name,
                    isConnected: true,
                    batteryLevel: battery,
                    icon: icon
                )
            }
            let snapshot = Snapshot(devices: infos, connectedCount: infos.count, isPoweredOn: powered)

            DispatchQueue.main.async {
                let current = Snapshot(
                    devices: self.devices,
                    connectedCount: self.connectedCount,
                    isPoweredOn: self.isPoweredOn
                )
                guard current != snapshot else { return }
                if self.devices != snapshot.devices { self.devices = snapshot.devices }
                if self.connectedCount != snapshot.connectedCount { self.connectedCount = snapshot.connectedCount }
                if self.isPoweredOn != snapshot.isPoweredOn { self.isPoweredOn = snapshot.isPoweredOn }
            }
        }
    }

    private static func batteryLevelsByAddress() -> [String: Int] {
        // Scan IORegistry once per update, then match all connected devices by
        // the same case-insensitive DeviceAddress used by the old lookup.
        let matching = IOServiceMatching("AppleHSBluetoothDevice")
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return [:]
        }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        var levels: [String: Int] = [:]
        while service != 0 {
            let current = service
            service = IOIteratorNext(iterator)
            defer { IOObjectRelease(current) }

            var props: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(current, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                  let dict = props?.takeRetainedValue() as? [String: Any] else { continue }

            guard let address = dict["DeviceAddress"] as? String else { continue }
            let key = address.lowercased()
            guard levels[key] == nil else { continue }
            if let level = dict["BatteryPercent"] as? Int {
                levels[key] = level
            } else if let level = dict["BatteryPercentSingle"] as? Int {
                levels[key] = level
            }
        }
        return levels
    }

    private static func iconName(for device: IOBluetoothDevice) -> String {
        let name = (device.name ?? "").lowercased()

        if name.contains("airpods") { return "airpodspro" }
        if name.contains("headphone") || name.contains("headset") || name.contains("beats") { return "headphones" }
        if name.contains("keyboard") { return "keyboard" }
        if name.contains("mouse") || name.contains("trackpad") || name.contains("magic") && name.contains("track") { return "computermouse" }
        if name.contains("speaker") || name.contains("homepod") { return "hifispeaker" }
        if name.contains("controller") || name.contains("gamepad") { return "gamecontroller" }

        let major = device.deviceClassMajor
        switch major {
        case 4: return "headphones"      // Audio
        case 5: return "keyboard"        // Peripheral
        case 6: return "camera"          // Imaging
        default: return "wave.3.right"
        }
    }
}
