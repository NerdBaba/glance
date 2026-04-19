import Foundation
import IOKit

// SMC key data types we care about
private enum SMCDataType: String {
    case ui8 = "ui8 ", sp78 = "sp78", flt = "flt "
}

// SMC command keys
private enum SMCKeys: UInt8 {
    case kernelIndex = 2, readBytes = 5, readKeyInfo = 9
}

// SMC key data struct — MUST match the exact layout the kernel expects
private struct SMCKeyData {
    typealias SMCBytes = (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                          UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                          UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                          UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)

    struct Vers {
        var major: CUnsignedChar = 0
        var minor: CUnsignedChar = 0
        var build: CUnsignedChar = 0
        var reserved: CUnsignedChar = 0
        var release: CUnsignedShort = 0
    }

    struct LimitData {
        var version: UInt16 = 0
        var length: UInt16 = 0
        var cpuPLimit: UInt32 = 0
        var gpuPLimit: UInt32 = 0
        var memPLimit: UInt32 = 0
    }

    struct KeyInfo {
        var dataSize: IOByteCount32 = 0
        var dataType: UInt32 = 0
        var dataAttributes: UInt8 = 0
    }

    var key: UInt32 = 0
    var vers = Vers()
    var pLimitData = LimitData()
    var keyInfo = KeyInfo()
    var padding: UInt16 = 0
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: SMCBytes = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
}

// SMC value container
private struct SMCVal {
    let key: String
    var dataSize: UInt32 = 0
    var dataType: String = ""
    var bytes: [UInt8] = Array(repeating: 0, count: 32)
}

// FourCharCode helpers
private extension FourCharCode {
    init(fromString str: String) {
        precondition(str.count == 4)
        self = str.utf8.reduce(0) { $0 << 8 | UInt32($1) }
    }

    func toString() -> String {
        String(UnicodeScalar(self >> 24 & 0xff)!)
            + String(UnicodeScalar(self >> 16 & 0xff)!)
            + String(UnicodeScalar(self >> 8 & 0xff)!)
            + String(UnicodeScalar(self & 0xff)!)
    }
}

/// Direct SMC sensor reader using IOKit AppleSMC connection.
/// Uses the same IOConnectCallStructMethod approach as the working test/smc_keys binary.
final class NativeSensorReader {
    private let conn: io_connect_t
    private let logger = AppLogger.shared

    init?() {
        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("AppleSMC")
        let status = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard status == kIOReturnSuccess else {
            NSLog("[Glance] SMC: IOServiceGetMatchingServices failed: 0x\(String(status, radix: 16))")
            return nil
        }
        let device = IOIteratorNext(iterator)
        IOObjectRelease(iterator)
        guard device != 0 else {
            NSLog("[Glance] SMC: AppleSMC device not found")
            return nil
        }

        var connection: io_connect_t = 0
        let openStatus = IOServiceOpen(device, mach_task_self_, 0, &connection)
        IOObjectRelease(device)
        guard openStatus == kIOReturnSuccess else {
            NSLog("[Glance] SMC: IOServiceOpen failed: 0x\(String(openStatus, radix: 16))")
            return nil
        }
        conn = connection
        NSLog("[Glance] SMC: Connected successfully (conn=0x\(String(conn, radix: 16)))")
    }

    deinit {
        IOServiceClose(conn)
    }

    var isAvailable: Bool { conn != 0 }

    /// Read a single SMC key and return its value as a Double.
    private func getValue(_ key: String) -> Double? {
        var val = SMCVal(key: key)

        // Step 1: Read key info (data size, type)
        var input = SMCKeyData()
        var output = SMCKeyData()
        input.key = FourCharCode(fromString: val.key)
        input.data8 = SMCKeys.readKeyInfo.rawValue

        let infoStatus = call(SMCKeys.kernelIndex.rawValue, input: &input, output: &output)
        guard infoStatus == kIOReturnSuccess else {
            return nil
        }

        val.dataSize = UInt32(output.keyInfo.dataSize)
        val.dataType = output.keyInfo.dataType.toString()

        // Step 2: Read actual bytes
        input.keyInfo.dataSize = output.keyInfo.dataSize
        input.data8 = SMCKeys.readBytes.rawValue

        let readStatus = call(SMCKeys.kernelIndex.rawValue, input: &input, output: &output)
        guard readStatus == kIOReturnSuccess else {
            return nil
        }

        // Copy bytes from output tuple to array
        let tupleMirror = Mirror(reflecting: output.bytes)
        for (i, child) in tupleMirror.children.enumerated() where i < Int(val.dataSize) {
            if let byte = child.value as? UInt8 {
                val.bytes[i] = byte
            }
        }

        // Parse based on data type
        switch val.dataType {
        case SMCDataType.sp78.rawValue:
            return Double(Int(val.bytes[0]) * 256 + Int(val.bytes[1])) / 256.0

        case SMCDataType.flt.rawValue:
            guard val.dataSize >= 4 else { return nil }
            return Double(val.bytes.withUnsafeBytes { $0.load(as: Float.self) })

        case SMCDataType.ui8.rawValue:
            return Double(val.bytes[0])

        default:
            return nil
        }
    }

    private func call(_ index: UInt8, input: inout SMCKeyData, output: inout SMCKeyData) -> kern_return_t {
        var outputSize = MemoryLayout<SMCKeyData>.stride
        return withUnsafeMutablePointer(to: &input) { inputPtr in
            withUnsafeMutablePointer(to: &output) { outputPtr in
                IOConnectCallStructMethod(
                    conn,
                    UInt32(index),
                    inputPtr,
                    MemoryLayout<SMCKeyData>.stride,
                    outputPtr,
                    &outputSize
                )
            }
        }
    }

    /// Read CPU temperature by averaging E-core and P-core sensors.
    func readCPUTemperature() -> Double? {
        let eCoreKeys = ["Te04", "Te05", "Te06", "Te08", "Te09", "Te0A"]
        let pCoreKeys = ["Tp00", "Tp01", "Tp02", "Tp04", "Tp05", "Tp06", "Tp08", "Tp09", "Tp0A"]

        var temps: [Double] = []

        for key in eCoreKeys + pCoreKeys {
            if let t = getValue(key) {
                temps.append(t)
            }
        }

        guard !temps.isEmpty else { return nil }
        return temps.reduce(0, +) / Double(temps.count)
    }

    /// Read fan RPM — returns first fan's actual speed.
    func readFanRPM() -> Int? {
        guard let fanCount = getValue("FNum") else { return nil }
        let count = Int(fanCount)
        guard count > 0 else { return nil }

        // Read first fan's actual RPM
        return Int(getValue("F0Ac") ?? 0)
    }

    /// Read total system power (PSTR = Power Standby).
    func readSystemPower() -> Double? {
        getValue("PSTR")
    }

    /// Read all three sensors in one call.
    func readAll() -> MactopSnapshot {
        let temp = readCPUTemperature() ?? 0
        let fan = readFanRPM() ?? 0
        let power = readSystemPower() ?? 0

        NSLog("[Glance] SMC readAll — Temp: %.1f  Fan: %d  Power: %.1f", temp, fan, power)

        return MactopSnapshot(
            cpuTemperatureCelsius: temp,
            fanRPM: fan,
            totalPowerWatts: power
        )
    }
}
