#!/usr/bin/env swift
import Foundation
import IOKit

// Look at AppleSMCKeysEndpoint which is the parent of temperature sensors
print("--- Looking for SMC Keys Endpoint ---")

var endpointIter: io_iterator_t = 0
if IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AppleSMCKeysEndpoint"), &endpointIter) == kIOReturnSuccess {
    var endpoint = IOIteratorNext(endpointIter)
    while endpoint != 0 {
        var ename = [CChar](repeating: 0, count: 128)
        IORegistryEntryGetName(endpoint, &ename)
        print("Endpoint: \(String(cString: ename))")
        
        var props: Unmanaged<CFMutableDictionary>?
        if IORegistryEntryCreateCFProperties(endpoint, &props, kCFAllocatorDefault, 0) == kIOReturnSuccess,
           let dict = props?.takeRetainedValue() as? [String: Any] {
            
            print("  Keys: \(dict.keys.sorted().prefix(20))")
            
            // Look for SMC keys that might contain temperature data
            for (k, v) in dict {
                if let data = v as? Data {
                    print("    \(k): Data(\(data.count) bytes)")
                } else if let arr = v as? [Any], arr.count > 0 {
                    if let first = arr.first as? NSNumber, first.doubleValue > 30 && first.doubleValue < 120 {
                        print("    \(k): \(arr.prefix(5).map { ($0 as? NSNumber)?.doubleValue ?? 0 })")
                    }
                }
            }
        }
        
        // Look for children
        var child: io_iterator_t = 0
        if IORegistryEntryGetChildIterator(endpoint, kIOServicePlane, &child) == kIOReturnSuccess {
            var c = IOIteratorNext(child)
            while c != 0 {
                var cname = [CChar](repeating: 0, count: 128)
                IORegistryEntryGetName(c, &cname)
                
                var cprops: Unmanaged<CFMutableDictionary>?
                if IORegistryEntryCreateCFProperties(c, &cprops, kCFAllocatorDefault, 0) == kIOReturnSuccess,
                   let cd = cprops?.takeRetainedValue() as? [String: Any] {
                    
                    for (k, v) in cd {
                        if let n = v as? NSNumber, n.doubleValue > 30 && n.doubleValue < 120 {
                            print("    Child \(String(cString: cname)) \(k): \(n.doubleValue)")
                        }
                    }
                }
                
                IOObjectRelease(c)
                c = IOIteratorNext(child)
            }
            IOObjectRelease(child)
        }
        
        IOObjectRelease(endpoint)
        endpoint = IOIteratorNext(endpointIter)
    }
    IOObjectRelease(endpointIter)
}

// Also check if there's an AppleSMC service with different approach
print("\n--- Checking AppleSMC children for SMCKeyData ---")

var smcIter: io_iterator_t = 0
if IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AppleSMC"), &smcIter) == kIOReturnSuccess {
    var smc = IOIteratorNext(smcIter)
    while smc != 0 {
        // Get children
        var child: io_iterator_t = 0
        if IORegistryEntryGetChildIterator(smc, kIOServicePlane, &child) == kIOReturnSuccess {
            var c = IOIteratorNext(child)
            while c != 0 {
                var cname = [CChar](repeating: 0, count: 128)
                IORegistryEntryGetName(c, &cname)
                let cn = String(cString: cname)
                
                if cn.contains("PMU") || cn.contains("pmu") || cn.contains("Sensor") {
                    print("Child: \(cn)")
                    
                    var cprops: Unmanaged<CFMutableDictionary>?
                    if IORegistryEntryCreateCFProperties(c, &cprops, kCFAllocatorDefault, 0) == kIOReturnSuccess,
                       let cd = cprops?.takeRetainedValue() as? [String: Any] {
                        
                        for (k, v) in cd {
                            if let n = v as? NSNumber {
                                let dv = n.doubleValue
                                if (dv > 30 && dv < 120) || (dv > 0 && dv < 300) {
                                    print("    \(k): \(dv)")
                                }
                            }
                        }
                    }
                }
                
                IOObjectRelease(c)
                c = IOIteratorNext(child)
            }
            IOObjectRelease(child)
        }
        
        IOObjectRelease(smc)
        smc = IOIteratorNext(smcIter)
    }
    IOObjectRelease(smcIter)
}