import AppKit
import Foundation
import CoreGraphics
import IOKit

// MARK: - Brightness APIs (loaded at runtime via dlopen)

// Strategy 1: DisplayServices.framework (works for BOTH built-in and external Apple displays)
private let displayServicesHandle: UnsafeMutableRawPointer? = {
    dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY)
}()

private typealias DSGetBrightnessFn = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
private typealias DSSetBrightnessFn = @convention(c) (UInt32, Float) -> Int32

private let _dsGetBrightness: DSGetBrightnessFn? = {
    guard let handle = displayServicesHandle,
          let sym = dlsym(handle, "DisplayServicesGetBrightness") else { return nil }
    return unsafeBitCast(sym, to: DSGetBrightnessFn.self)
}()

private let _dsSetBrightness: DSSetBrightnessFn? = {
    guard let handle = displayServicesHandle,
          let sym = dlsym(handle, "DisplayServicesSetBrightness") else { return nil }
    return unsafeBitCast(sym, to: DSSetBrightnessFn.self)
}()

// Strategy 2: CoreDisplay.framework (fallback — built-in displays only)
private let coreDisplayHandle: UnsafeMutableRawPointer? = {
    dlopen("/System/Library/Frameworks/CoreDisplay.framework/CoreDisplay", RTLD_LAZY)
}()

private typealias CDGetBrightnessFn = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
private typealias CDSetBrightnessFn = @convention(c) (UInt32, Float) -> Int32

private let _cdGetBrightness: CDGetBrightnessFn? = {
    guard let handle = coreDisplayHandle,
          let sym = dlsym(handle, "CoreDisplay_Display_GetUserBrightness") else { return nil }
    return unsafeBitCast(sym, to: CDGetBrightnessFn.self)
}()

private let _cdSetBrightness: CDSetBrightnessFn? = {
    guard let handle = coreDisplayHandle,
          let sym = dlsym(handle, "CoreDisplay_Display_SetUserBrightness") else { return nil }
    return unsafeBitCast(sym, to: CDSetBrightnessFn.self)
}()

// MARK: - Strategy 3: IOKit IODisplayGetFloatParameter (some external monitors)

private func findDisplayService(for displayID: CGDirectDisplayID) -> io_service_t {
    var iter: io_iterator_t = 0
    let matching = IOServiceMatching("IODisplayConnect")
    guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iter) == KERN_SUCCESS else {
        return IO_OBJECT_NULL
    }
    defer { IOObjectRelease(iter) }

    var service = IOIteratorNext(iter)
    while service != IO_OBJECT_NULL {
        var vendorID: Int32 = 0
        var productID: Int32 = 0

        if let cfVendor = IORegistryEntryCreateCFProperty(service, "DisplayVendorID" as CFString, kCFAllocatorDefault, 0) {
            if let v = cfVendor.takeRetainedValue() as? Int32 { vendorID = v }
        }
        if let cfProduct = IORegistryEntryCreateCFProperty(service, "DisplayProductID" as CFString, kCFAllocatorDefault, 0) {
            if let p = cfProduct.takeRetainedValue() as? Int32 { productID = p }
        }

        let cgVendor = CGDisplayVendorNumber(displayID)
        let cgProduct = CGDisplayModelNumber(displayID)

        if vendorID == Int32(cgVendor) && productID == Int32(cgProduct) {
            return service
        }

        IOObjectRelease(service)
        service = IOIteratorNext(iter)
    }

    return IO_OBJECT_NULL
}

// MARK: - Brightness Provider Selection

private enum BrightnessBackend {
    case displayServices
    case coreDisplay
    case iokit(io_service_t)
    case none
}

private func detectBackend(displayID: UInt32) -> BrightnessBackend {
    // Try DisplayServices first (supports external Apple displays + built-in)
    if let getFn = _dsGetBrightness {
        var value: Float = 0
        let result = getFn(displayID, &value)
        if result == 0 {
            return .displayServices
        }
    }

    // Fall back to CoreDisplay (built-in only)
    if let getFn = _cdGetBrightness {
        var value: Float = 0
        let result = getFn(displayID, &value)
        if result == 0 {
            return .coreDisplay
        }
    }

    // Try IOKit IODisplayGetFloatParameter (some external monitors via DDC)
    let service = findDisplayService(for: displayID)
    if service != IO_OBJECT_NULL {
        var brightness: Float = 0
        let result = IODisplayGetFloatParameter(service, 0, kIODisplayBrightnessKey as CFString, &brightness)
        if result == kIOReturnSuccess {
            return .iokit(service)
        }
        IOObjectRelease(service)
    }

    return .none
}

// MARK: - ViewModel

final class BrightnessViewModel: ObservableObject {
    @Published var brightness: Float = 1.0
    @Published var isAvailable: Bool = false
    @Published var displayName: String = "Main Display"
    @Published var backendDescription: String = "Unavailable"

    private var timer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private let displayID: UInt32
    private let backend: BrightnessBackend

    init() {
        displayID = CGMainDisplayID()
        backend = detectBackend(displayID: displayID)
        displayName = Self.displayName(for: displayID)
        if case .none = backend {
            isAvailable = false
        } else {
            isAvailable = true
        }
        backendDescription = Self.backendDescription(for: backend)

        if isAvailable {
            readBrightness()
            timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
                self?.readBrightness()
            }
            timer?.tolerance = 0.5
        }

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.readBrightness()
        }
    }

    deinit {
        timer?.invalidate()
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
        if case .iokit(let service) = backend {
            IOObjectRelease(service)
        }
    }

    private func readBrightness() {
        var value: Float = 0
        var success = false

        switch backend {
        case .displayServices:
            if let fn = _dsGetBrightness {
                success = fn(displayID, &value) == 0
            }
        case .coreDisplay:
            if let fn = _cdGetBrightness {
                success = fn(displayID, &value) == 0
            }
        case .iokit(let service):
            success = IODisplayGetFloatParameter(service, 0, kIODisplayBrightnessKey as CFString, &value) == kIOReturnSuccess
        case .none:
            return
        }

        if success {
            let clamped = max(0, min(1, value))
            if abs(brightness - clamped) > 0.005 {
                brightness = clamped
            }
        }
    }

    func setBrightness(_ value: Float) {
        let clamped = max(0, min(1, value))

        switch backend {
        case .displayServices:
            if let fn = _dsSetBrightness {
                _ = fn(displayID, clamped)
            }
        case .coreDisplay:
            if let fn = _cdSetBrightness {
                _ = fn(displayID, clamped)
            }
        case .iokit(let service):
            IODisplaySetFloatParameter(service, 0, kIODisplayBrightnessKey as CFString, clamped)
        case .none:
            return
        }

        brightness = clamped
    }

    func adjustBrightness(by delta: Float) {
        setBrightness(brightness + delta)
    }

    var brightnessPercent: Int {
        Int(round(brightness * 100))
    }

    var iconName: String {
        if brightness < 0.01 {
            return "sun.min"
        } else if brightness < 0.5 {
            return "sun.max"
        } else {
            return "sun.max.fill"
        }
    }

    private static func backendDescription(for backend: BrightnessBackend) -> String {
        switch backend {
        case .displayServices:
            return "DisplayServices"
        case .coreDisplay:
            return "CoreDisplay"
        case .iokit:
            return "IOKit"
        case .none:
            return "Unavailable"
        }
    }

    private static func displayName(for displayID: CGDirectDisplayID) -> String {
        NSScreen.screens.first(where: { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return false
            }
            return number.uint32Value == displayID
        })?.localizedName ?? "Main Display"
    }
}
