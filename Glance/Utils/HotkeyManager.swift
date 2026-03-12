import Carbon.HIToolbox
import Foundation

final class HotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    var onToggle: (() -> Void)?

    private static var instance: HotkeyManager?

    func register(modifiers: UInt32, keyCode: UInt32) {
        unregister()

        HotkeyManager.instance = self

        let hotKeyID = EventHotKeyID(
            signature: OSType(0x474C4E43),  // "GLNC"
            id: 1
        )

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handler: EventHandlerUPP = { _, event, _ -> OSStatus in
            HotkeyManager.instance?.onToggle?()
            return noErr
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )

        RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
        }
    }

    deinit {
        unregister()
    }

    /// Parse a hotkey string like "ctrl+option+b" into modifier flags and key code.
    static func parse(_ hotkeyString: String) -> (modifiers: UInt32, keyCode: UInt32)? {
        let parts = hotkeyString.lowercased().components(separatedBy: "+").map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        guard parts.count >= 2 else { return nil }

        var modifiers: UInt32 = 0
        var keyCode: UInt32?

        for part in parts {
            switch part {
            case "ctrl", "control":
                modifiers |= UInt32(controlKey)
            case "option", "alt", "opt":
                modifiers |= UInt32(optionKey)
            case "shift":
                modifiers |= UInt32(shiftKey)
            case "cmd", "command":
                modifiers |= UInt32(cmdKey)
            default:
                if let code = keyCodeMap[part] {
                    keyCode = code
                }
            }
        }

        guard let kc = keyCode else { return nil }
        return (modifiers, kc)
    }

    private static let keyCodeMap: [String: UInt32] = [
        "a": 0x00, "b": 0x0B, "c": 0x08, "d": 0x02, "e": 0x0E,
        "f": 0x03, "g": 0x05, "h": 0x04, "i": 0x22, "j": 0x26,
        "k": 0x28, "l": 0x25, "m": 0x2E, "n": 0x2D, "o": 0x1F,
        "p": 0x23, "q": 0x0C, "r": 0x0F, "s": 0x01, "t": 0x11,
        "u": 0x20, "v": 0x09, "w": 0x0D, "x": 0x07, "y": 0x10,
        "z": 0x06,
        "1": 0x12, "2": 0x13, "3": 0x14, "4": 0x15, "5": 0x17,
        "6": 0x16, "7": 0x1A, "8": 0x1C, "9": 0x19, "0": 0x1D,
        "space": 0x31, "escape": 0x35, "return": 0x24, "tab": 0x30,
    ]
}
