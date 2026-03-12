import AppKit
import Foundation
import IOBluetooth

struct BluetoothDeviceInfo: Identifiable {
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

    private var timer: Timer?
    private var wakeObserver: NSObjectProtocol?

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
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
                DispatchQueue.main.async { self?.devices = []; self?.connectedCount = 0 }
                return
            }

            let connected = paired.filter { $0.isConnected() }
            let infos = connected.map { device -> BluetoothDeviceInfo in
                let name = device.name ?? "Unknown"
                let battery = Self.batteryLevel(for: device)
                let icon = Self.iconName(for: device)
                return BluetoothDeviceInfo(
                    id: device.addressString ?? name,
                    name: name,
                    isConnected: true,
                    batteryLevel: battery,
                    icon: icon
                )
            }

            DispatchQueue.main.async {
                self?.devices = infos
                self?.connectedCount = infos.count
            }
        }
    }

    private static func batteryLevel(for device: IOBluetoothDevice) -> Int? {
        // Try IORegistry for battery info (works for AirPods and some BT devices)
        let matching = IOServiceMatching("AppleHSBluetoothDevice")
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer { IOObjectRelease(service); service = IOIteratorNext(iterator) }

            var props: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                  let dict = props?.takeRetainedValue() as? [String: Any] else { continue }

            // Match by address
            if let addr = dict["DeviceAddress"] as? String,
               let deviceAddr = device.addressString,
               addr.lowercased() == deviceAddr.lowercased() {
                if let level = dict["BatteryPercent"] as? Int {
                    return level
                }
                if let level = dict["BatteryPercentSingle"] as? Int {
                    return level
                }
            }
        }
        return nil
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
