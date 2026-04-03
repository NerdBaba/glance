#!/usr/bin/env swift
import Foundation
import IOKit

let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
guard service != IO_OBJECT_NULL else { print("No AppleSMC"); exit(1) }
defer { IOObjectRelease(service) }

var conn: io_connect_t = 0
let result = IOServiceOpen(service, mach_task_self_, 0, &conn)
if result != kIOReturnSuccess { print("Failed to open: \(result)"); exit(1) }
defer { IOServiceClose(conn) }

print("SMC opened, trying fan keys...")

// Try reading with different approaches
func readKey(_ key: String, selector: UInt32) -> (success: Bool, data: [UInt8]) {
    var input = [UInt8](repeating: 0, count: 80)
    var output = [UInt8](repeating: 0, count: 80)
    var outSize = 80
    
    let kb = Array(key.utf8)
    if kb.count >= 4 {
        input[0] = kb[0]
        input[1] = kb[1]
        input[2] = kb[2]
        input[3] = kb[3]
    }
    
    // Try different selectors
    // Selector 2 is standard, selector 0 might work too
    input[42] = UInt8(selector)
    
    let r = IOConnectCallStructMethod(conn, 2, &input, 80, &output, &outSize)
    return (r == kIOReturnSuccess, output)
}

// First get fan count
var f0Output = [UInt8](repeating: 0, count: 80)
var f0Input = [UInt8](repeating: 0, count: 80)
var outSize = 80

let fkb = Array("F0Ac".utf8)
f0Input[0] = fkb[0]
f0Input[1] = fkb[1]
f0Input[2] = fkb[2]
f0Input[3] = fkb[3]
f0Input[42] = 5

let f0Result = IOConnectCallStructMethod(conn, 2, &f0Input, 80, &f0Output, &outSize)
print("F0Ac: success=\(f0Result == kIOReturnSuccess), dataSize=\(f0Output[28])")

if f0Result == kIOReturnSuccess && f0Output[28] > 0 {
    let dataSize = Int(f0Output[28])
    if dataSize == 4 {
        var f: Float = 0
        memcpy(&f, &f0Output[48], 4)
        print("F0Ac = \(f) RPM")
    } else if dataSize == 2 {
        var v: UInt16 = 0
        memcpy(&v, &f0Output[48], 2)
        print("F0Ac = \(Double(v)/4.0) RPM (fpe2)")
    }
}

// Try selector 0 (raw read)
var f0Output2 = [UInt8](repeating: 0, count: 80)
var f0Input2 = [UInt8](repeating: 0, count: 80)
var outSize2 = 80

let fkb2 = Array("F0Ac".utf8)
f0Input2[0] = fkb2[0]
f0Input2[1] = fkb2[1]
f0Input2[2] = fkb2[2]
f0Input2[3] = fkb2[3]
f0Input2[42] = 0

let f0Result2 = IOConnectCallStructMethod(conn, 2, &f0Input2, 80, &f0Output2, &outSize2)
print("F0Ac selector 0: success=\(f0Result2 == kIOReturnSuccess), status=\(f0Output2[41])")

// Try reading key info first then read
print("\nTrying key info + read approach...")
for key in ["F0Ac", "F0Mn", "F0Mx", "FNum"] {
    // Get key info
    var infoInput = [UInt8](repeating: 0, count: 80)
    var infoOutput = [UInt8](repeating: 0, count: 80)
    var outSize = 80
    
    let kb = Array(key.utf8)
    if kb.count >= 4 {
        infoInput[0] = kb[0]
        infoInput[1] = kb[1]
        infoInput[2] = kb[2]
        infoInput[3] = kb[3]
    }
    infoInput[42] = 9  // Read key info
    
    let infoResult = IOConnectCallStructMethod(conn, 2, &infoInput, 80, &infoOutput, &outSize)
    
    if infoResult == kIOReturnSuccess && infoOutput[28] > 0 {
        let dataSize = Int(infoOutput[28])
        print("\(key): dataSize=\(dataSize), type=\(infoOutput[32..<36].map { $0 })")
        
        // Now read the value
        var readInput = [UInt8](repeating: 0, count: 80)
        readInput[0] = kb[0]
        readInput[1] = kb[1]
        readInput[2] = kb[2]
        readInput[3] = kb[3]
        readInput[42] = 5  // Read bytes
        
        var readOutput = [UInt8](repeating: 0, count: 80)
        outSize = 80
        
        let readResult = IOConnectCallStructMethod(conn, 2, &readInput, 80, &readOutput, &outSize)
        
        if readResult == kIOReturnSuccess {
            if dataSize == 4 {
                var f: Float = 0
                memcpy(&f, &readOutput[48], 4)
                print("  -> \(f)")
            } else if dataSize == 2 {
                var v: UInt16 = 0
                memcpy(&v, &readOutput[48], 2)
                print("  -> \(Double(v)/4.0)")
            } else if dataSize > 0 {
                let bytes = readOutput[48..<(48+dataSize)]
                print("  -> \(bytes.map { String(format: "%02x", $0) }))")
            }
        } else {
            print("  -> read failed: \(readResult)")
        }
    } else {
        print("\(key): info failed or no data")
    }
}

// Also check what's available in IORegistry under AppleSMC
print("\n--- Checking AppleSMC children ---")
var child: io_iterator_t = 0
if IORegistryEntryGetChildIterator(service, kIOServicePlane, &child) == kIOReturnSuccess {
    var c = IOIteratorNext(child)
    while c != 0 {
        var name = [CChar](repeating: 0, count: 128)
        IORegistryEntryGetName(c, &name)
        print("Child: \(String(cString: name))")
        
        var props: Unmanaged<CFMutableDictionary>?
        if IORegistryEntryCreateCFProperties(c, &props, kCFAllocatorDefault, 0) == kIOReturnSuccess,
           let dict = props?.takeRetainedValue() as? [String: Any] {
            let fanKeys = dict.keys.filter { $0.hasPrefix("F") }
            if !fanKeys.isEmpty {
                print("  Fan keys: \(fanKeys)")
                for k in fanKeys.prefix(3) {
                    if let v = dict[k] {
                        print("    \(k): \(v)")
                    }
                }
            }
        }
        IOObjectRelease(c)
        c = IOIteratorNext(child)
    }
    IOObjectRelease(child)
}