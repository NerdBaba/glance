import CoreLocation
import CoreWLAN
import Network
import SwiftUI

enum NetworkState: String {
    case connected = "Connected"
    case connectedWithoutInternet = "No Internet"
    case connecting = "Connecting"
    case disconnected = "Disconnected"
    case disabled = "Disabled"
    case notSupported = "Not Supported"
}

enum WifiSignalStrength: String {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case unknown = "Unknown"

    var signalBars: Int {
        switch self {
        case .high: return 3
        case .medium: return 2
        case .low: return 1
        case .unknown: return 0
        }
    }

    var qualityLabel: String {
        switch self {
        case .high: return "Excellent"
        case .medium: return "Good"
        case .low: return "Weak"
        case .unknown: return "N/A"
        }
    }
}

/// Unified view model for monitoring network and Wi‑Fi status.
final class NetworkStatusViewModel: NSObject, ObservableObject,
    CLLocationManagerDelegate
{
    static let shared = NetworkStatusViewModel()

    // States for Wi‑Fi and Ethernet obtained via NWPathMonitor.
    @Published var wifiState: NetworkState = .disconnected
    @Published var ethernetState: NetworkState = .disconnected

    // Wi‑Fi details obtained via CoreWLAN.
    @Published var ssid: String = "Not connected"
    @Published var ssidUnavailable = false
    var isWiFiAssociated: Bool { wifiState == .connected || wifiState == .connectedWithoutInternet }
    var signalPercentage: Double? { isWiFiAssociated && rssi < 0 ? min(100, max(0, Double(rssi + 100) * 2)) : nil }
    @Published var rssi: Int = 0
    @Published var noise: Int = 0
    @Published var channel: String = "N/A"
    @Published var bandLabel: String = ""
    @Published var txRate: Double = 0  // Mbps

    // Network speed tracking
    @Published var downloadSpeed: Double = 0  // bytes/s
    @Published var uploadSpeed: Double = 0    // bytes/s
    private var previousBytesIn: UInt64 = 0
    private var previousBytesOut: UInt64 = 0
    private var previousSpeedUptime: TimeInterval = 0
    private var speedTimer: Timer?
    private var throughputConsumers: Set<UUID> = []
    private var throughputGeneration = 0
    private let samplingQueue = DispatchQueue(label: "NetworkSampling", qos: .utility)

    // Local IP
    @Published var localIP: String = "N/A"

    /// Computed property for signal strength.
    var wifiSignalStrength: WifiSignalStrength {
        // If Wi‑Fi is not connected or the interface is missing – return unknown.
        if !isWiFiAssociated || rssi >= 0 {
            return .unknown
        }
        if rssi >= -50 {
            return .high
        } else if rssi >= -70 {
            return .medium
        } else {
            return .low
        }
    }

    private let monitor = NWPathMonitor()
    private let wifiMonitor = NWPathMonitor(requiredInterfaceType: .wifi)
    private var wifiPathStatus: NWPath.Status = .unsatisfied
    private var wifiInterfaceName: String?
    private var lastDiagnostic: String?
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")

    private var timer: Timer?
    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        if CommandLine.arguments.contains("--export-bar") || CommandLine.arguments.contains("--preview-settings") { return }
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        startNetworkMonitoring()
        startWiFiMonitoring()
        updateLocalIP()
    }

    deinit {
        stopNetworkMonitoring()
        stopWiFiMonitoring()
        speedTimer?.invalidate()
    }

    // MARK: — NWPathMonitor for overall network status.

    private func startNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            DispatchQueue.main.async {
                // Ethernet
                if path.availableInterfaces.contains(where: {
                    $0.type == .wiredEthernet
                }) {
                    if path.usesInterfaceType(.wiredEthernet) {
                        switch path.status {
                        case .satisfied:
                            self.ethernetState = .connected
                        case .requiresConnection:
                            self.ethernetState = .connecting
                        default:
                            self.ethernetState = .disconnected
                        }
                    } else {
                        self.ethernetState = .disconnected
                    }
                } else {
                    self.ethernetState = .notSupported
                }
            }
        }
        monitor.start(queue: monitorQueue)
        // A Wi-Fi-only path survives VPN/Ethernet routing changes. The default
        // path describes routing, not whether the radio is associated.
        wifiMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                guard let self else { return }
                self.wifiPathStatus = path.status
                self.wifiInterfaceName = path.availableInterfaces.first(where: { $0.type == .wifi })?.name
                self.updateWiFiInfo()
                self.updateLocalIP()
            }
        }
        wifiMonitor.start(queue: monitorQueue)
    }

    private func stopNetworkMonitoring() {
        monitor.cancel()
        wifiMonitor.cancel()
    }

    // MARK: — Updating Wi‑Fi information via CoreWLAN.

    private func startWiFiMonitoring() {
        // SSID/RSSI/channel don't change rapidly — 10s is enough
        timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) {
            [weak self] _ in
            self?.updateWiFiInfo()
        }
        updateWiFiInfo()
    }

    private func stopWiFiMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func updateWiFiInfo() {
        let client = CWWiFiClient.shared()
        let interfaces = client.interfaces() ?? []
        let preferred = interfaces.first(where: { $0.interfaceName == wifiInterfaceName })
            ?? interfaces.first(where: { $0.interfaceMode() == .station }) ?? client.interface()
        if let interface = preferred {
            let associated = interface.powerOn() && (interface.interfaceMode() == .station || wifiPathStatus == .satisfied)
            wifiState = !interface.powerOn() ? .disabled : associated
                ? (wifiPathStatus == .satisfied ? .connected : .connectedWithoutInternet)
                : (wifiPathStatus == .requiresConnection ? .connecting : .disconnected)
            let name = interface.ssid().flatMap { $0.isEmpty ? nil : $0 }
            ssidUnavailable = associated && name == nil
            self.ssid = associated ? (name ?? "Wi-Fi") : "Not connected"
            self.rssi = interface.rssiValue()
            self.noise = interface.noiseMeasurement()
            self.txRate = interface.transmitRate()
            if let wlanChannel = interface.wlanChannel() {
                let band: String
                switch wlanChannel.channelBand {
                case .bandUnknown:
                    band = "unknown"
                case .band2GHz:
                    band = "2.4GHz"
                case .band5GHz:
                    band = "5GHz"
                case .band6GHz:
                    band = "6GHz"
                @unknown default:
                    band = "unknown"
                }
                self.bandLabel = band
                self.channel = "\(wlanChannel.channelNumber) (\(band))"
            } else {
                self.bandLabel = ""
                self.channel = "N/A"
            }
        } else {
            wifiState = wifiPathStatus == .satisfied ? .connected : .notSupported
            ssidUnavailable = wifiPathStatus == .satisfied
            // No SSID is available; retain a truthful association fallback.
            self.ssid = wifiPathStatus == .satisfied ? "Wi-Fi" : "No interface"
            self.rssi = 0
            self.noise = 0
            self.channel = "N/A"
            self.bandLabel = ""
            self.txRate = 0
        }
        let diagnostic = "Wi-Fi state=\(wifiState.rawValue), nameAvailable=\(!ssidUnavailable), signalAvailable=\(rssi < 0), locationAuthorization=\(locationManager.authorizationStatus.rawValue)"
        if diagnostic != lastDiagnostic { AppLogger.shared.info(diagnostic); lastDiagnostic = diagnostic }
        updateLocalIP()
    }

    // MARK: — Network Speed Monitoring

    /// Reference-count demand across bars and popups. A status-only label
    /// needs Wi-Fi events, not a recurring interface-byte scan.
    func setThroughputDemand(_ id: UUID, enabled: Bool) {
        if enabled { throughputConsumers.insert(id) }
        else { throughputConsumers.remove(id) }
        if !throughputConsumers.isEmpty, speedTimer == nil {
            throughputGeneration += 1
            if downloadSpeed != 0 { downloadSpeed = 0 }
            if uploadSpeed != 0 { uploadSpeed = 0 }
            startSpeedMonitoring()
        } else if throughputConsumers.isEmpty, speedTimer != nil {
            throughputGeneration += 1
            speedTimer?.invalidate()
            speedTimer = nil
        }
    }

    private func startSpeedMonitoring() {
        // Serialize interface counters off the main thread. The timer cadence
        // and baseline/delta behavior remain unchanged.
        samplingQueue.async { [weak self] in
            guard let self else { return }
            (self.previousBytesIn, self.previousBytesOut) = self.getNetworkBytes()
            self.previousSpeedUptime = ProcessInfo.processInfo.systemUptime
        }

        speedTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) {
            [weak self] _ in
            self?.updateNetworkSpeed()
        }
    }

    private func updateNetworkSpeed() {
        let generation = throughputGeneration
        samplingQueue.async { [weak self] in
            guard let self else { return }
            self.sampleNetworkSpeed(generation: generation)
        }
    }

    private func sampleNetworkSpeed(generation: Int) {
        let (bytesIn, bytesOut) = getNetworkBytes()
        let now = ProcessInfo.processInfo.systemUptime
        let interval = max(0.001, now - previousSpeedUptime)
        previousSpeedUptime = now

        let deltaIn = bytesIn >= previousBytesIn ? bytesIn - previousBytesIn : 0
        let deltaOut = bytesOut >= previousBytesOut ? bytesOut - previousBytesOut : 0

        DispatchQueue.main.async {
            guard generation == self.throughputGeneration, !self.throughputConsumers.isEmpty else { return }
            let download = Double(deltaIn) / interval
            let upload = Double(deltaOut) / interval
            if self.downloadSpeed != download { self.downloadSpeed = download }
            if self.uploadSpeed != upload { self.uploadSpeed = upload }
        }

        previousBytesIn = bytesIn
        previousBytesOut = bytesOut
    }

    private func getNetworkBytes() -> (UInt64, UInt64) {
        var ifaddrs: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrs) == 0, let firstAddr = ifaddrs else {
            return (0, 0)
        }
        defer { freeifaddrs(ifaddrs) }

        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0

        var ptr = firstAddr
        while true {
            let flags = Int32(ptr.pointee.ifa_flags)
            let isUp = (flags & IFF_UP) != 0
            let isLoopback = (flags & IFF_LOOPBACK) != 0

            if isUp && !isLoopback {
                guard let pointer = ptr.pointee.ifa_addr else { if let next = ptr.pointee.ifa_next { ptr = next; continue }; break }
                let addr = pointer.pointee
                if addr.sa_family == UInt8(AF_LINK) {
                    if let data = ptr.pointee.ifa_data {
                        let networkData = data.assumingMemoryBound(to: if_data.self).pointee
                        totalIn += UInt64(networkData.ifi_ibytes)
                        totalOut += UInt64(networkData.ifi_obytes)
                    }
                }
            }

            guard let next = ptr.pointee.ifa_next else { break }
            ptr = next
        }

        return (totalIn, totalOut)
    }

    // MARK: — Local IP

    private func updateLocalIP() {
        let preferredInterface = wifiInterfaceName
        samplingQueue.async { [weak self] in
            guard let self else { return }
            let ip = self.readLocalIP(preferredInterface: preferredInterface)
            DispatchQueue.main.async {
                if self.localIP != ip { self.localIP = ip }
            }
        }
    }

    private func readLocalIP(preferredInterface: String?) -> String {
        var ifaddrs: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrs) == 0, let firstAddr = ifaddrs else {
            return "N/A"
        }
        defer { freeifaddrs(ifaddrs) }

        var ip = "N/A"
        var ptr = firstAddr
        while true {
            let interface = ptr.pointee
            guard let address = interface.ifa_addr else { if let next = ptr.pointee.ifa_next { ptr = next; continue }; break }
            let addrFamily = address.pointee.sa_family
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == preferredInterface || (preferredInterface == nil && name.hasPrefix("en")) {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(
                        interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                        &hostname, socklen_t(hostname.count),
                        nil, 0, NI_NUMERICHOST
                    ) == 0 {
                        ip = String(cString: hostname)
                        break
                    }
                }
            }
            guard let next = ptr.pointee.ifa_next else { break }
            ptr = next
        }

        return ip
    }

    // MARK: — Speed Formatting

    static func formatSpeed(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond < 1024 {
            return String(format: "%.0f B/s", bytesPerSecond)
        } else if bytesPerSecond < 1024 * 1024 {
            return String(format: "%.1f KB/s", bytesPerSecond / 1024)
        } else {
            return String(format: "%.1f MB/s", bytesPerSecond / (1024 * 1024))
        }
    }

    // MARK: — CLLocationManagerDelegate.

    func locationManager(
        _ manager: CLLocationManager,
        didChangeAuthorization status: CLAuthorizationStatus
    ) {
        updateWiFiInfo()
        updateLocalIP()
    }
}
