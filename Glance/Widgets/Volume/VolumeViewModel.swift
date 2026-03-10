import AudioToolbox
import Foundation

/// C callback for CoreAudio property changes — forwards to VolumeViewModel.
private func audioPropertyListener(
    _ objectID: AudioObjectID,
    _ numberAddresses: UInt32,
    _ addresses: UnsafePointer<AudioObjectPropertyAddress>,
    _ clientData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let clientData = clientData else { return noErr }
    let vm = Unmanaged<VolumeViewModel>.fromOpaque(clientData).takeUnretainedValue()
    for i in 0..<Int(numberAddresses) {
        let selector = addresses[i].mSelector
        if selector == kAudioHardwareServiceDeviceProperty_VirtualMainVolume
            || selector == kAudioDevicePropertyMute
        {
            DispatchQueue.main.async { vm.updateVolume() }
        } else if selector == kAudioHardwarePropertyDefaultOutputDevice {
            DispatchQueue.main.async {
                // Device changed — re-register listeners on new device
                vm.reregisterDeviceListeners()
                vm.updateVolume()
                vm.updateOutputDeviceName()
            }
        }
    }
    return noErr
}

final class VolumeViewModel: ObservableObject {
    @Published var volume: Float = 0.0
    @Published var isMuted: Bool = false
    @Published var outputDeviceName: String = ""

    private var currentListeningDevice: AudioObjectID = 0
    private var refcon: UnsafeMutableRawPointer?

    init() {
        refcon = Unmanaged.passUnretained(self).toOpaque()
        updateVolume()
        updateOutputDeviceName()
        addDefaultDeviceListener()
        if let deviceID = getDefaultOutputDevice() {
            addDeviceListeners(deviceID)
        }
    }

    deinit {
        removeDefaultDeviceListener()
        removeDeviceListeners()
    }

    // MARK: - CoreAudio Listeners (event-driven, no polling)

    private func addDefaultDeviceListener() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &address, audioPropertyListener, refcon
        )
    }

    private func removeDefaultDeviceListener() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &address, audioPropertyListener, refcon
        )
    }

    private func addDeviceListeners(_ deviceID: AudioObjectID) {
        currentListeningDevice = deviceID

        var volumeAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListener(deviceID, &volumeAddr, audioPropertyListener, refcon)

        var muteAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListener(deviceID, &muteAddr, audioPropertyListener, refcon)
    }

    private func removeDeviceListeners() {
        guard currentListeningDevice != 0 else { return }
        let deviceID = currentListeningDevice

        var volumeAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListener(deviceID, &volumeAddr, audioPropertyListener, refcon)

        var muteAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListener(deviceID, &muteAddr, audioPropertyListener, refcon)

        currentListeningDevice = 0
    }

    /// Called when default output device changes — re-register volume/mute listeners on new device.
    func reregisterDeviceListeners() {
        removeDeviceListeners()
        if let deviceID = getDefaultOutputDevice() {
            addDeviceListeners(deviceID)
        }
    }

    // MARK: - Read State

    func updateVolume() {
        guard let deviceID = getDefaultOutputDevice() else { return }

        var volume: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            deviceID, &address, 0, nil, &size, &volume)
        if status == noErr, self.volume != volume {
            self.volume = volume
        }

        var mute: UInt32 = 0
        var muteSize = UInt32(MemoryLayout<UInt32>.size)
        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        let muteStatus = AudioObjectGetPropertyData(
            deviceID, &muteAddress, 0, nil, &muteSize, &mute)
        if muteStatus == noErr {
            let newMuted = mute != 0
            if self.isMuted != newMuted {
                self.isMuted = newMuted
            }
        }
    }

    // MARK: - Set State

    func setVolume(_ newVolume: Float) {
        guard let deviceID = getDefaultOutputDevice() else { return }

        var vol = max(0, min(1, newVolume))
        let size = UInt32(MemoryLayout<Float32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &vol)
        self.volume = vol
    }

    func toggleMute() {
        guard let deviceID = getDefaultOutputDevice() else { return }

        var mute: UInt32 = isMuted ? 0 : 1
        let size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &mute)
        self.isMuted = !self.isMuted
    }

    func adjustVolume(by delta: Float) {
        setVolume(volume + delta)
    }

    // MARK: - Device Info

    private func getDefaultOutputDevice() -> AudioObjectID? {
        var deviceID = AudioObjectID(0)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &size, &deviceID
        )

        return status == noErr ? deviceID : nil
    }

    var volumeIconName: String {
        if isMuted || volume == 0 {
            return "speaker.slash.fill"
        } else if volume < 0.33 {
            return "speaker.wave.1.fill"
        } else if volume < 0.66 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }

    var volumePercent: Int {
        Int(round(volume * 100))
    }

    func updateOutputDeviceName() {
        guard let deviceID = getDefaultOutputDevice() else { return }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size) == noErr else { return }

        var name: Unmanaged<CFString>?
        let status = withUnsafeMutablePointer(to: &name) { ptr in
            AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, ptr)
        }
        if status == noErr, let cfName = name?.takeUnretainedValue() {
            let deviceName = cfName as String
            if self.outputDeviceName != deviceName {
                self.outputDeviceName = deviceName
            }
        }
    }

    var outputDeviceIcon: String {
        let lower = outputDeviceName.lowercased()
        if lower.contains("airpods") {
            return "airpodspro"
        } else if lower.contains("headphone") || lower.contains("headset") {
            return "headphones"
        } else if lower.contains("bluetooth") || lower.contains("beats") {
            return "hifispeaker"
        } else if lower.contains("display") || lower.contains("hdmi") || lower.contains("tv") {
            return "tv"
        } else {
            return "hifispeaker.2"
        }
    }
}
