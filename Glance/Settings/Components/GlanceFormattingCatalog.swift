import Foundation

/// The UI names options by purpose; on-disk keys retain import compatibility.
enum GlanceFormattingCatalog {
    static func title(_ key: String) -> String {
        if key == "format" { return "Layout" }
        if key == "label" { return "Text" }
        if key.hasPrefix("font-"), let number = Int(key.dropFirst(5)) { return "Component font \(number + 1)" }
        let names = ["format": "Layout", "label": "Text", "ramp": "Icon ramp", "bar": "Progress bar", "ws": "Space",
            "foreground": "Text color", "background": "Background", "maxlen": "Maximum length", "minlen": "Minimum length",
            "prev": "Previous", "ellipsis": "Truncate with ellipsis", "framerate": "Frame duration (ms)", "font": "Font index",
            "exec": "Command", "if": "Condition", "env": "Environment", "token": "Live value", "native": "Data", "mpd": "Playback", "alsa": "Volume"]
        return key.split(separator: "-").map { names[String($0)] ?? String($0).capitalized }.joined(separator: " · ")
    }
    static func isFormatting(_ key: String) -> Bool {
        ["format", "label", "font-", "icon-", "ramp-", "bar-", "ws-icon-", "animation-"].contains { key.hasPrefix($0) }
            && !["format-background", "format-foreground", "format-background-opacity", "format-padding", "format-padding-left", "format-padding-right", "format-height", "format-radius", "format-shape", "format-min-width", "format-alignment", "format-offset-y", "format-tracking", "format-font-name", "format-font-size", "format-font-weight", "format-border-color", "format-border-width", "format-prefix"].contains(key)
    }
    static func isColor(_ key: String) -> Bool {
        key.hasSuffix("foreground") || key.hasSuffix("background") || key.hasSuffix("-color") || key.hasSuffix("-underline") || key.hasSuffix("-overline") || key.range(of: "-foreground-[0-9]+$", options: .regularExpression) != nil
    }
    static func isIcon(_ key: String) -> Bool {
        key.hasSuffix("-prefix") || key.hasSuffix("-suffix") || key.hasPrefix("icon-") && !isColor(key) && !key.hasSuffix("-font") && !key.hasSuffix("-padding") ||
        (key.hasPrefix("ramp-") || key.hasPrefix("animation-")) && Int(key.split(separator: "-").last ?? "") != nil ||
        key.hasPrefix("bar-") && ["-fill", "-empty", "-indicator"].contains(where: { key.hasSuffix($0) }) || key == "ws-icon-default"
    }
    static func components(_ values: ConfigData) -> [String] {
        var result = Set(["label"])
        for key in values.keys {
            if key == "label" || key.hasPrefix("label-") && !["-foreground", "-background", "-font", "-padding", "-margin", "-maxlen", "-minlen", "-ellipsis", "-alignment", "-underline", "-overline", "-prefix", "-suffix"].contains(where: { key.hasSuffix($0) }) { result.insert(key) }
            if ["ramp-", "animation-"].contains(where: { key.hasPrefix($0) }), let end = key.lastIndex(of: "-"), Int(key[key.index(after: end)...]) != nil { result.insert(String(key[..<end])) }
            if key.hasPrefix("bar-"), key.hasSuffix("-width") { result.insert(String(key.dropLast(6))) }
        }
        if values["native-source"]?.stringValue == "music" {
            result.insert("label-toggle")
            for name in ["prev", "next", "play", "pause", "stop"] where values["icon-" + name] != nil { result.insert("label-" + name) }
        }
        return result.sorted()
    }
    static func tokenNames(source: String?) -> [String] {
        switch source {
        case "music": return ["title", "artist", "album", "song-details", "elapsed", "total", "percentage"]
        case "network": return ["essid", "local_ip", "percentage", "downspeed", "upspeed", "downspeed-compact", "upspeed-compact"]
        case "date": return ["date", "time"]
        case "disk": return ["mountpoint", "used", "free", "total", "used-gb", "free-gb", "percentage"]
        case "memory": return ["percentage", "gb_used", "gb_free", "gb_total", "mb_used"]
        case "workspaces": return ["index", "name", "icon", "nwin"]
        case "window": return ["title", "name"]
        case "keyboard": return ["layout", "layout-lower", "name"]
        case "temperature": return ["temperature-c", "temperature-f", "percentage"]
        case "bluetooth": return ["power", "count", "output"]
        case "updates": return ["count"]
        case "weather": return ["temperature", "feels-like", "condition"]
        case "volume", "microphone", "brightness", "cpu": return ["percentage", "value"]
        default: return ["output", "percentage", "value", "counter", "pid", "user", "host"]
        }
    }
    static func tokenTitle(_ key: String) -> String {
        let names = ["essid": "Wi-Fi name", "local_ip": "Local IP address", "gb_used": "Memory used (GB)", "gb_total": "Total memory (GB)", "nwin": "Window count", "elapsed": "Elapsed time", "total": "Duration", "index": "Space number"]
        return (names[key] ?? key.replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "-", with: " ").capitalized) + "  %" + key + "%"
    }
    static func tokens(source: String?, output: String) -> [String: String] {
        ["output": ["network", "bluetooth"].contains(source ?? "") ? "Connected" : output, "title": source == "window" ? "Terminal" : "Beauty and the Beast", "artist": "Nightwish", "album": "Angels Fall First", "elapsed": "0:39", "total": source == "disk" ? "500 GB" : "6:24",
         "essid": "Home Wi-Fi", "local_ip": "192.168.1.24", "interface": "en0", "signal": "86", "downspeed": "24 KB/s", "upspeed": "8 KB/s", "downspeed-compact": "24 K", "upspeed-compact": "8 K",
         "date": "Fri Oct 9", "time": "11:45 AM", "used": "180 GB", "free": "320 GB", "used-gb": "180 GB", "free-gb": "320 GB", "gb_used": "6.7", "gb_free": "9.3", "gb_total": "16", "mb_used": "6860",
         "index": "2", "name": source == "keyboard" ? "English" : source == "workspaces" ? "2" : "Terminal", "icon": "●", "nwin": "3", "layout": "EN", "layout-lower": "en", "temperature-c": "48", "temperature-f": "118", "power": "on", "count": "1", "mountpoint": "/", "temperature": "24", "feels-like": "22", "location": "Home", "condition": "Clear", "percentage-core1": "15", "percentage-core2": "22"]
    }
    static let suggestions: [(String, String, String)] = [
        ("format-online", "<label>", "text"), ("format-offline", "<label-offline>", "text"), ("format-muted", "<label-muted>", "text"), ("format-fail", "<label-fail>", "text"),
        ("label-online", "%output%", "text"), ("label-offline", "Offline", "text"), ("label-muted", "Muted", "text"), ("label-fail", "Unavailable", "text"),
        ("label-foreground", "pywal:7", "text"), ("label-background", "pywal:0", "text"), ("label-padding", "1", "number"), ("label-margin", "0", "number"),
        ("label-font", "1", "number"), ("label-maxlen", "30", "number"), ("label-minlen", "0", "number"), ("label-ellipsis", "true", "bool"),
        ("label-alignment", "left", "text"), ("label-underline", "pywal:4", "text"), ("label-overline", "pywal:4", "text"),
        ("format-suffix", "", "text"), ("font-0", "SFMono-Regular:size=14", "text"), ("font-1", "SFMono-Regular:size=14", "text"),
        ("value-min", "0", "number"), ("value-max", "100", "number"), ("value-index", "0", "number"), ("value-regex", "([0-9.]+)", "text"),
        ("interval-fail", "5", "number"), ("interval-if", "5", "number"), ("animation-progress-0", "◐", "text"), ("animation-progress-1", "◓", "text"), ("animation-progress-framerate", "1000", "number")
    ]
}
