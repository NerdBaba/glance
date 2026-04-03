#!/usr/bin/env swift
import Foundation
import IOKit

// Search for temperature and fan related services
func findServices(matching: String) {
    var iterator: io_iterator_t = 0
    let result = IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching(matching), &iterator)
    if result != kIOReturnSuccess { return }
    defer { IOObjectRelease(iterator) }
    
    var service = IOIteratorNext(iterator)
    while service != 0 {
        var props: Unmanaged<CFMutableDictionary>?
        if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == kIOReturnSuccess,
           let dict = props?.takeRetainedValue() as? [String: Any] {
            let keys = dict.keys.filter { $0.hasPrefix("T") || $0.hasPrefix("F") || $0.contains("Temp") || $0.contains("Fan") }
            if !keys.isEmpty {
                print("\(matching): \(keys.prefix(10))")
                for k in keys.prefix(3) {
                    if let val = dict[k] {
                        print("  \(k): \(val)")
                    }
                }
            }
        }
        IOObjectRelease(service)
        service = IOIteratorNext(iterator)
    }
}

print("Searching for SMC-related services...")
findServices(matching: "AppleSMC")
findServices(matching: "AppleARMIODevice")
findServices(matching: "AppleCLPC")
findServices(matching: "AppleActuatorDevice")
findServices(matching: "AppleSensor")

// Try reading via IOReport
print("\n--- Checking hwmon ---")
var hwmonIter: io_iterator_t = 0
if IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AppleSMC"), &hwmonIter) == kIOReturnSuccess {
    var serv = IOIteratorNext(hwmonIter)
    while serv != 0 {
        print("Service: \(serv)")
        
        // Look at children
        var child: io_iterator_t = 0
        if IORegistryEntryGetChildIterator(serv, kIOServicePlane, &child) == kIOReturnSuccess {
            var c = IOIteratorNext(child)
            while c != 0 {
                var cprops: Unmanaged<CFMutableDictionary>?
                if IORegistryEntryCreateCFProperties(c, &cprops, kCFAllocatorDefault, 0) == kIOReturnSuccess,
                   let cd = cprops?.takeRetainedValue() as? [String: Any] {
                    let sensorKeys = cd.keys.filter { $0.contains("temperature") || $0.contains("fan") || $0.contains("Temp") || $0.contains("Fan") }
                    if !sensorKeys.isEmpty {
                        print("  Child \(c): \(sensorKeys)")
                    }
                }
                IOObjectRelease(c)
                c = IOIteratorNext(child)
            }
            IOObjectRelease(child)
        }
        
        IOObjectRelease(serv)
        serv = IOIteratorNext(hwmonIter)
    }
    IOObjectRelease(hwmonIter)
}