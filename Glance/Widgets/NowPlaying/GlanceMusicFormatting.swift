import Foundation

/// Optional friendly music layout. Imported layouts remain authoritative until
/// the user enables these controls; time has its own untruncated component.
enum GlanceMusicFormatting {
    static func applying(to config: ConfigData) -> ConfigData {
        guard config["music-details-enabled"]?.boolValue == true else { return config }
        var values = config
        values["label-song"] = .string("%song-details%")
        values["label-song-maxlen"] = .int(0)
        values["label-song-ellipsis"] = .bool(true)
        let elapsed = config["music-show-elapsed"]?.boolValue ?? true
        let total = config["music-show-duration"]?.boolValue ?? true
        values["label-time"] = .string(elapsed && total ? "%elapsed% / %total%" : elapsed ? "%elapsed%" : total ? "%total%" : "")
        values.removeValue(forKey: "label-time-maxlen")
        // Keep each theme's media controls and their positions intact.
        var layout = config["format-online"]?.stringValue ?? config["format"]?.stringValue ?? "<label-song>"
        layout = layout.replacingOccurrences(of: "<label-time>", with: "")
            .replacingOccurrences(of: "<bar-music-progress>", with: "")
        let details = "<label-song>" + (elapsed || total ? " <label-time>" : "")
            + ((config["music-show-progress"]?.boolValue ?? false) ? " <bar-music-progress>" : "")
        if layout.contains("<label-song>") { layout = layout.replacingOccurrences(of: "<label-song>", with: details) }
        else if layout.contains("<label>") { layout = layout.replacingOccurrences(of: "<label>", with: details) }
        else { layout += " " + details }
        values["format-online"] = .string(layout)
        for (key, fallback) in [("width", "12"), ("fill", "━"), ("empty", "─"), ("indicator", "●")] {
            let name = "bar-music-progress-" + key
            if values[name] == nil { values[name] = key == "width" ? .int(12) : .string(fallback) }
        }
        return values
    }

    static func details(title: String, artist: String, album: String, config: ConfigData) -> String {
        let parts = [("title", title, true, config["music-details-maxlen"]?.intValue ?? 24),
                     ("artist", artist, true, config["music-artist-maxlen"]?.intValue ?? 18),
                     ("album", album, false, config["music-album-maxlen"]?.intValue ?? 18)]
        return parts.compactMap { name, text, fallback, limit -> String? in
            guard (config["music-show-" + name]?.boolValue ?? fallback), !text.isEmpty else { return nil }
            return limit > 0 && text.count > limit ? String(text.prefix(max(1, limit - 1))) + "…" : text
        }.joined(separator: config["music-detail-separator"]?.stringValue ?? " — ")
    }

    static func time(_ seconds: Double?) -> String {
        guard let seconds, seconds.isFinite, seconds >= 0 else { return "—:—" }
        return formatPlaybackTime(seconds)
    }
}
