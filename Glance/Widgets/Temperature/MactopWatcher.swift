import AppKit
import Combine
import Foundation

/// Sensor snapshot — the three values Glance widgets consume.
struct MactopSnapshot {
    let cpuTemperatureCelsius: Double
    let fanRPM: Int
    let totalPowerWatts: Double
}

/// Native SMC sensor watcher — polls AppleSMC keys via IOKit.
/// No subprocess, no sudo required.
final class MactopWatcher: ObservableObject {
    static let shared = MactopWatcher()

    @Published var snapshot: MactopSnapshot?
    @Published var isRunning = false

    private var nativeSensor: NativeSensorReader?
    private var nativeTimer: Timer?
    private let logger = AppLogger.shared

    // Dedup state
    private var lastTemp: Double = -1
    private var lastFan: Int = -1
    private var lastPower: Double = -1
    private var lastUpdateTime: Date = .distantPast
    private let tempThreshold: Double = 0.5
    private let fanThreshold: Int = 50
    private let powerThreshold: Double = 0.3
    private let minUpdateInterval: TimeInterval = 2.0

    private init() {}

    func start() {
        guard !isRunning else { return }
        isRunning = true

        // Create native SMC sensor
        if let sensor = NativeSensorReader(), sensor.isAvailable {
            nativeSensor = sensor
            logger.info("NativeSensorReader initialized — using IOKit SMC", category: .temperature)
        } else {
            logger.error("NativeSensorReader failed to initialize — SMC not available", category: .temperature)
            return
        }

        // Initial read
        pollSensors()

        // Set up 2-second poll timer
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.nativeTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                self?.pollSensors()
            }
            self.nativeTimer?.tolerance = 0.5
        }
    }

    func stop() {
        isRunning = false
        nativeTimer?.invalidate()
        nativeTimer = nil
        nativeSensor = nil
    }

    private func pollSensors() {
        guard let sensor = nativeSensor, isRunning else { return }

        let now = Date()
        guard now.timeIntervalSince(lastUpdateTime) >= minUpdateInterval else { return }

        let snapshot = sensor.readAll()

        if snapshot.cpuTemperatureCelsius > 0 {
            logger.info(
                String(format: "SMC sensors — Temp: %.1f°C  Fan: %d RPM  Power: %.1fW",
                       snapshot.cpuTemperatureCelsius,
                       snapshot.fanRPM,
                       snapshot.totalPowerWatts),
                category: .temperature
            )
        } else {
            logger.warning("SMC returned zero temperature — sensor may have failed", category: .temperature)
        }

        publishIfChanged(snapshot: snapshot, now: now)
    }

    private func publishIfChanged(snapshot: MactopSnapshot, now: Date) {
        let tempChanged = abs(snapshot.cpuTemperatureCelsius - lastTemp) >= tempThreshold
        let fanChanged = abs(snapshot.fanRPM - lastFan) >= fanThreshold
        let powerChanged = abs(snapshot.totalPowerWatts - lastPower) >= powerThreshold

        guard tempChanged || fanChanged || powerChanged else { return }

        lastUpdateTime = now
        if tempChanged { lastTemp = snapshot.cpuTemperatureCelsius }
        if fanChanged { lastFan = snapshot.fanRPM }
        if powerChanged { lastPower = snapshot.totalPowerWatts }

        DispatchQueue.main.async { [weak self] in
            self?.snapshot = snapshot
        }
    }
}
