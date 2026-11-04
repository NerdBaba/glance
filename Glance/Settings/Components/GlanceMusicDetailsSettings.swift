import SwiftUI

struct GlanceMusicDetailsSettings: View {
    let id: String
    private var editor: ModuleSettingsEditor { .init(id: id) }

    var body: some View {
        SettingsSection(title: "Track details & playback time", keywords: [", value: editor.integer(", "Detail separator", "Show album", "Show artist", "Show duration", "Show elapsed time", "Show progress bar", "Show track title", "Use detail controls", "music-album-maxlen", "music-artist-maxlen", "music-detail-separator", "music-details-enabled", "music-details-maxlen", "music-show-album", "music-show-artist", "music-show-duration", "music-show-elapsed", "music-show-progress", "music-show-title"]) {
            Toggle("Customize track details", isOn: editor.bool("music-details-enabled"))
            Text("Keeps the current player controls and colors. Playback time stays visible independently of the track text.")
                .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if editor.values["music-details-enabled"]?.boolValue == true {
                Toggle("Show track title", isOn: editor.bool("music-show-title", default: true))
                Toggle("Show artist", isOn: editor.bool("music-show-artist", default: true))
                Toggle("Show album", isOn: editor.bool("music-show-album"))
                Toggle("Show elapsed time", isOn: editor.bool("music-show-elapsed", default: true))
                Toggle("Show duration", isOn: editor.bool("music-show-duration", default: true))
                Toggle("Show progress bar", isOn: editor.bool("music-show-progress"))
                SettingsTextField(label: "Detail separator", value: editor.string("music-detail-separator", default: " — "))
                Stepper("Title limit: \(editor.integer("music-details-maxlen", default: 24).wrappedValue) characters", value: editor.integer("music-details-maxlen", default: 24), in: 8...120)
                Stepper("Artist limit: \(editor.integer("music-artist-maxlen", default: 18).wrappedValue) characters", value: editor.integer("music-artist-maxlen", default: 18), in: 8...120)
                Stepper("Album limit: \(editor.integer("music-album-maxlen", default: 18).wrappedValue) characters", value: editor.integer("music-album-maxlen", default: 18), in: 8...120)
                GlanceModulePreview(values: editor.values)
            } else {
                Text("Choose a ready-made label above, or turn on custom track details.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
