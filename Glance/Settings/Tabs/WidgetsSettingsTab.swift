import SwiftUI
import UniformTypeIdentifiers

/// Wrapper giving each widget row a stable UUID identity for drag-and-drop.
private struct IdentifiedWidget: Identifiable, Equatable {
    let id = UUID()
    var item: TomlWidgetItem

    static func == (lhs: IdentifiedWidget, rhs: IdentifiedWidget) -> Bool {
        lhs.id == rhs.id
    }
}

struct WidgetsSettingsTab: View {
    @ObservedObject var configManager = ConfigManager.shared
    @State private var activeWidgets: [IdentifiedWidget] = []
    @State private var draggedItem: IdentifiedWidget?

    @State private var batteryShowPercentage = true
    @State private var batteryWarningLevel = 30
    @State private var batteryCriticalLevel = 10

    @State private var volumeShowPercentage = false
    @State private var volumeScrollStep = 3.0

    @State private var brightnessShowPercentage = false
    @State private var brightnessScrollStep = 3.0

    @State private var weatherProvider = "met-no"
    @State private var weatherUseIPFallback = true
    @State private var weatherUsesManualLocation = false
    @State private var weatherLocationName = ""
    @State private var weatherLatitude = ""
    @State private var weatherLongitude = ""

    @State private var nowPlayingShowIcon = true
    @State private var nowPlayingShowTitle = true
    @State private var nowPlayingShowArtist = false
    @State private var nowPlayingShowAlbum = false
    @State private var nowPlayingTitleMaxLength = 30
    @State private var nowPlayingArtistMaxLength = 20
    @State private var nowPlayingAlbumMaxLength = 20
    @State private var nowPlayingSeparator = " - "
    @State private var nowPlayingShowVisualizer = true
    @State private var nowPlayingVisualizerPosition = "right"

    // Volume display mode settings
    @State private var volumeDisplayMode = "icon-value"
    @State private var volumeLabel = ""
    @State private var volumeMaxLength = 10

    // System Monitor CPU settings
    @State private var systemMonitorCpuDisplayMode = "icon-value"
    @State private var systemMonitorCpuLabel = ""
    @State private var systemMonitorCpuMaxLength = 10

    // System Monitor Memory settings
    @State private var systemMonitorMemDisplayMode = "icon-value"
    @State private var systemMonitorMemLabel = ""
    @State private var systemMonitorMemMaxLength = 10

    // Temperature settings
    @State private var temperatureDisplayMode = "icon-value"
    @State private var temperatureLabel = ""
    @State private var temperatureMaxLength = 10

    // Fan settings
    @State private var fanDisplayMode = "icon-value"
    @State private var fanLabel = ""
    @State private var fanMaxLength = 10

    // Energy settings
    @State private var energyDisplayMode = "icon-value"
    @State private var energyLabel = ""
    @State private var energyMaxLength = 10

    // Battery display mode settings
    @State private var batteryDisplayMode = "icon-value"
    @State private var batteryLabel = ""
    @State private var batteryMaxLength = 10

    // Bluetooth settings
    @State private var bluetoothDisplayMode = "icon-value"
    @State private var bluetoothLabel = ""
    @State private var bluetoothMaxLength = 10

    // Brightness display mode settings
    @State private var brightnessDisplayMode = "icon-value"
    @State private var brightnessLabel = ""
    @State private var brightnessMaxLength = 10

    // Network WiFi settings
    @State private var networkWifiDisplayMode = "icon-value"
    @State private var networkWifiLabel = ""
    @State private var networkWifiMaxLength = 10

    // Network Ethernet settings
    @State private var networkEthDisplayMode = "icon-value"
    @State private var networkEthLabel = ""
    @State private var networkEthMaxLength = 10

    private let allAvailableWidgets: [(id: String, label: String, icon: String)] = [
        ("default.spaces", "Spaces", "rectangle.3.group"),
        ("default.activeapp", "Active App", "app.badge.fill"),
        ("default.nowplaying", "Now Playing", "music.note"),
        ("default.volume", "Volume", "speaker.wave.2"),
        ("default.network", "Network", "wifi"),
        ("default.battery", "Battery", "battery.75percent"),
        ("default.weather", "Weather", "cloud.sun"),
        ("default.systemmonitor", "System Monitor", "gauge.medium"),
        ("default.disk", "Disk", "internaldrive"),
        ("default.pomodoro", "Pomodoro", "timer"),
        ("default.inputlanguage", "Input Language", "keyboard"),
        ("default.brightness", "Brightness", "sun.max"),
        ("default.clipboard", "Clipboard", "doc.on.clipboard"),
        ("default.bluetooth", "Bluetooth", "wave.3.right"),
        ("default.temperature", "Temperature", "thermometer"),
        ("default.fan", "Fan Speed", "fan"),
        ("default.energy", "Energy", "bolt.fill"),
        ("default.time", "Time", "clock"),
        ("spacer", "Spacer", "arrow.left.and.right"),
        ("divider", "Divider", "minus"),
    ]

    private let weatherProviders: [(id: String, label: String)] = [
        ("met-no", "MET Norway"),
        ("open-meteo", "Open-Meteo"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SettingsSection(title: "Active Widgets") {
                    Text("Drag to reorder. Click - to remove.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(activeWidgets) { widget in
                        let index = activeWidgets.firstIndex(where: { $0.id == widget.id })!
                        HStack {
                            Image(systemName: "line.3.horizontal")
                                .foregroundStyle(.tertiary)

                            Image(systemName: iconFor(widget.item.id))
                                .frame(width: 20)

                            Text(labelFor(widget.item.id))
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Button(action: {
                                removeWidget(widget)
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)

                            Button(action: { moveWidget(widget, direction: -1) }) {
                                Image(systemName: "chevron.up")
                            }
                            .buttonStyle(.plain)
                            .disabled(index == 0)

                            Button(action: { moveWidget(widget, direction: 1) }) {
                                Image(systemName: "chevron.down")
                            }
                            .buttonStyle(.plain)
                            .disabled(index == activeWidgets.count - 1)
                        }
                        .padding(.vertical, 4)
                        .onDrag {
                            draggedItem = widget
                            return NSItemProvider(object: widget.id.uuidString as NSString)
                        }
                        .onDrop(of: [.text], delegate: WidgetDropDelegate(
                            targetItem: widget,
                            activeWidgets: $activeWidgets,
                            draggedItem: $draggedItem,
                            onDrop: { writeWidgetList() }
                        ))
                    }
                }

                SettingsSection(title: "Add Widget") {
                    let inactive = allAvailableWidgets.filter { widget in
                        if widget.id == "spacer" || widget.id == "divider" { return true }
                        return !activeWidgets.contains(where: { $0.item.id == widget.id })
                    }

                    if inactive.isEmpty {
                        Text("All widgets are active")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(inactive, id: \.id) { widget in
                            HStack {
                                Image(systemName: widget.icon)
                                    .frame(width: 20)
                                Text(widget.label)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Button(action: {
                                    addWidget(widget.id)
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(.green)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                SettingsSection(title: "Battery") {
                    Toggle("Show percentage in bar", isOn: $batteryShowPercentage)
                        .onChange(of: batteryShowPercentage) { _, newValue in
                            configManager.updateConfigValue(
                                key: "widgets.default.battery.show-percentage",
                                newValue: newValue ? "true" : "false"
                            )
                        }

                    StepperRow(
                        label: "Warning level",
                        value: $batteryWarningLevel,
                        range: 5...80,
                        suffix: "%"
                    ) {
                        clampBatteryThresholds(changed: .warning)
                    }

                    StepperRow(
                        label: "Critical level",
                        value: $batteryCriticalLevel,
                        range: 1...50,
                        suffix: "%"
                    ) {
                        clampBatteryThresholds(changed: .critical)
                    }

                    Text("These thresholds control low-battery colors in the bar and popup.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                SettingsSection(title: "Volume") {
                    Toggle("Show percentage in bar", isOn: $volumeShowPercentage)
                        .onChange(of: volumeShowPercentage) { _, newValue in
                            configManager.updateConfigValue(
                                key: "widgets.default.volume.show-percentage",
                                newValue: newValue ? "true" : "false"
                            )
                        }

                    SliderRow(
                        label: "Scroll step",
                        value: $volumeScrollStep,
                        range: 1...10,
                        step: 1,
                        format: "%.0f%%"
                    ) {
                        configManager.updateConfigValue(
                            key: "widgets.default.volume.scroll-step",
                            newValue: String(Int(volumeScrollStep.rounded()))
                        )
                    }

                    Text("Mouse wheel changes system volume by this amount.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                SettingsSection(title: "Volume Display") {
                    Picker("Display mode", selection: $volumeDisplayMode) {
                        Text("Icon").tag("icon")
                        Text("Value").tag("value")
                        Text("Label + Value").tag("label-value")
                        Text("Icon + Value").tag("icon-value")
                        Text("Icon + Label + Value").tag("icon-label-value")
                        Text("Off").tag("off")
                    }
                    .pickerStyle(.menu)
                    .onChange(of: volumeDisplayMode) { _, newValue in
                        configManager.updateConfigValue(
                            key: "widgets.default.volume.display-mode",
                            newValue: newValue
                        )
                    }

                    TextField("Label", text: $volumeLabel)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: volumeLabel) { _, newValue in
                            configManager.updateConfigValue(
                                key: "widgets.default.volume.label",
                                newValue: newValue
                            )
                        }

                    StepperRow(
                        label: "Max text length",
                        value: $volumeMaxLength,
                        range: 3...40,
                        suffix: " chars"
                    ) {
                        configManager.updateConfigValue(
                            key: "widgets.default.volume.max-length",
                            newValue: String(volumeMaxLength)
                        )
                    }
                }

                SettingsSection(title: "Brightness") {
                    Toggle("Show percentage in bar", isOn: $brightnessShowPercentage)
                        .onChange(of: brightnessShowPercentage) { _, newValue in
                            configManager.updateConfigValue(
                                key: "widgets.default.brightness.show-percentage",
                                newValue: newValue ? "true" : "false"
                            )
                        }

                    SliderRow(
                        label: "Scroll step",
                        value: $brightnessScrollStep,
                        range: 1...10,
                        step: 1,
                        format: "%.0f%%"
                    ) {
                        configManager.updateConfigValue(
                            key: "widgets.default.brightness.scroll-step",
                            newValue: String(Int(brightnessScrollStep.rounded()))
                        )
                    }

                    Text("Mouse wheel changes display brightness by this amount when control is available.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                SettingsSection(title: "Weather") {
                    HStack {
                        Text("Provider")
                            .frame(width: 130, alignment: .leading)
                        Picker("Provider", selection: $weatherProvider) {
                            ForEach(weatherProviders, id: \.id) { provider in
                                Text(provider.label).tag(provider.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: weatherProvider) { _, newValue in
                            configManager.updateConfigValue(
                                key: "widgets.default.weather.provider",
                                newValue: newValue
                            )
                        }
                    }

                    Toggle("Use IP fallback when system location fails", isOn: $weatherUseIPFallback)
                        .onChange(of: weatherUseIPFallback) { _, newValue in
                            configManager.updateConfigValue(
                                key: "widgets.default.weather.use-ip-fallback",
                                newValue: newValue ? "true" : "false"
                            )
                        }

                    Toggle("Use manual coordinates", isOn: $weatherUsesManualLocation)
                        .onChange(of: weatherUsesManualLocation) { _, enabled in
                            if !enabled {
                                clearWeatherManualLocation()
                            }
                        }

                    if weatherUsesManualLocation {
                        HStack {
                            Text("Location name")
                                .frame(width: 130, alignment: .leading)
                            TextField("Optional", text: $weatherLocationName)
                                .textFieldStyle(.roundedBorder)
                        }

                        HStack {
                            Text("Latitude")
                                .frame(width: 130, alignment: .leading)
                            TextField("55.7558", text: $weatherLatitude)
                                .textFieldStyle(.roundedBorder)
                        }

                        HStack {
                            Text("Longitude")
                                .frame(width: 130, alignment: .leading)
                            TextField("37.6173", text: $weatherLongitude)
                                .textFieldStyle(.roundedBorder)
                        }

                        HStack {
                            Spacer()
                            Button("Apply Manual Location") {
                                commitWeatherManualLocation()
                            }
                            .disabled(parsedWeatherLatitude == nil || parsedWeatherLongitude == nil)
                        }
                    }

                    Text("Manual coordinates give the most stable weather if macOS location is inconsistent.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                SettingsSection(title: "Now Playing") {
                    Toggle("Show music icon", isOn: $nowPlayingShowIcon)
                        .onChange(of: nowPlayingShowIcon) { _, newValue in
                            configManager.updateConfigValue(
                                key: "widgets.default.nowplaying.show-icon",
                                newValue: newValue ? "true" : "false"
                            )
                        }

                    Toggle("Show title", isOn: $nowPlayingShowTitle)
                        .onChange(of: nowPlayingShowTitle) { _, newValue in
                            configManager.updateConfigValue(
                                key: "widgets.default.nowplaying.show-title",
                                newValue: newValue ? "true" : "false"
                            )
                        }

                    StepperRow(
                        label: "Title max length",
                        value: $nowPlayingTitleMaxLength,
                        range: 5...80,
                        suffix: " chars"
                    ) {
                        configManager.updateConfigValue(
                            key: "widgets.default.nowplaying.title-max-length",
                            newValue: String(nowPlayingTitleMaxLength)
                        )
                    }

                    Toggle("Show artist", isOn: $nowPlayingShowArtist)
                        .onChange(of: nowPlayingShowArtist) { _, newValue in
                            configManager.updateConfigValue(
                                key: "widgets.default.nowplaying.show-artist",
                                newValue: newValue ? "true" : "false"
                            )
                        }

                    StepperRow(
                        label: "Artist max length",
                        value: $nowPlayingArtistMaxLength,
                        range: 5...60,
                        suffix: " chars"
                    ) {
                        configManager.updateConfigValue(
                            key: "widgets.default.nowplaying.artist-max-length",
                            newValue: String(nowPlayingArtistMaxLength)
                        )
                    }

                    Toggle("Show album", isOn: $nowPlayingShowAlbum)
                        .onChange(of: nowPlayingShowAlbum) { _, newValue in
                            configManager.updateConfigValue(
                                key: "widgets.default.nowplaying.show-album",
                                newValue: newValue ? "true" : "false"
                            )
                        }

                    StepperRow(
                        label: "Album max length",
                        value: $nowPlayingAlbumMaxLength,
                        range: 5...60,
                        suffix: " chars"
                    ) {
                        configManager.updateConfigValue(
                            key: "widgets.default.nowplaying.album-max-length",
                            newValue: String(nowPlayingAlbumMaxLength)
                        )
                    }

                    HStack {
                        Text("Separator")
                            .frame(width: 130, alignment: .leading)
                        TextField("Separator", text: $nowPlayingSeparator)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: nowPlayingSeparator) { _, newValue in
                                configManager.updateConfigValue(
                                    key: "widgets.default.nowplaying.separator",
                                    newValue: newValue
                                )
                            }
                    }

                    Divider()

                    Toggle("Show visualizer bars", isOn: $nowPlayingShowVisualizer)
                        .onChange(of: nowPlayingShowVisualizer) { _, newValue in
                            configManager.updateConfigValue(
                                key: "widgets.default.nowplaying.show-visualizer",
                                newValue: newValue ? "true" : "false"
                            )
                        }

                    HStack {
                        Text("Visualizer position")
                            .frame(width: 130, alignment: .leading)
                        Picker("Visualizer position", selection: $nowPlayingVisualizerPosition) {
                            ForEach(VisualizerPosition.allCases, id: \.rawValue) { pos in
                                Text(pos.label).tag(pos.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: nowPlayingVisualizerPosition) { _, newValue in
                            configManager.updateConfigValue(
                                key: "widgets.default.nowplaying.visualizer-position",
                                newValue: newValue
                            )
                        }
                    }
                    .disabled(!nowPlayingShowVisualizer)

                    Text("Enabled fields are joined by the separator. Example: \"Song Title - Artist - Album\"")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                SettingsSection(title: "System Monitor (CPU)") {
                    Picker("Display mode", selection: $systemMonitorCpuDisplayMode) {
                        Text("Icon").tag("icon")
                        Text("Value").tag("value")
                        Text("Label + Value").tag("label-value")
                        Text("Icon + Value").tag("icon-value")
                        Text("Icon + Label + Value").tag("icon-label-value")
                        Text("Off").tag("off")
                    }
                    .pickerStyle(.menu)
                    .onChange(of: systemMonitorCpuDisplayMode) { _, newValue in
                        configManager.updateConfigValue(
                            key: "widgets.default.systemmonitor.cpu-display-mode",
                            newValue: newValue
                        )
                    }

                    TextField("Label", text: $systemMonitorCpuLabel)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: systemMonitorCpuLabel) { _, newValue in
                            configManager.updateConfigValue(
                                key: "widgets.default.systemmonitor.cpu-label",
                                newValue: newValue
                            )
                        }

                    StepperRow(
                        label: "Max text length",
                        value: $systemMonitorCpuMaxLength,
                        range: 3...40,
                        suffix: " chars"
                    ) {
                        configManager.updateConfigValue(
                            key: "widgets.default.systemmonitor.cpu-max-length",
                            newValue: String(systemMonitorCpuMaxLength)
                        )
                    }
                }

                SettingsSection(title: "System Monitor (Memory)") {
                    Picker("Display mode", selection: $systemMonitorMemDisplayMode) {
                        Text("Icon").tag("icon")
                        Text("Value").tag("value")
                        Text("Label + Value").tag("label-value")
                        Text("Icon + Value").tag("icon-value")
                        Text("Icon + Label + Value").tag("icon-label-value")
                        Text("Off").tag("off")
                    }
                    .pickerStyle(.menu)
                    .onChange(of: systemMonitorMemDisplayMode) { _, newValue in
                        configManager.updateConfigValue(
                            key: "widgets.default.systemmonitor.mem-display-mode",
                            newValue: newValue
                        )
                    }

                    TextField("Label", text: $systemMonitorMemLabel)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: systemMonitorMemLabel) { _, newValue in
                            configManager.updateConfigValue(
                                key: "widgets.default.systemmonitor.mem-label",
                                newValue: newValue
                            )
                        }

                    StepperRow(
                        label: "Max text length",
                        value: $systemMonitorMemMaxLength,
                        range: 3...40,
                        suffix: " chars"
                    ) {
                        configManager.updateConfigValue(
                            key: "widgets.default.systemmonitor.mem-max-length",
                            newValue: String(systemMonitorMemMaxLength)
                        )
                    }
                }

                SettingsSection(title: "Temperature") {
                    Picker("Display mode", selection: $temperatureDisplayMode) {
                        Text("Icon").tag("icon")
                        Text("Value").tag("value")
                        Text("Label + Value").tag("label-value")
                        Text("Icon + Value").tag("icon-value")
                        Text("Icon + Label + Value").tag("icon-label-value")
                        Text("Off").tag("off")
                    }
                    .pickerStyle(.menu)
                    .onChange(of: temperatureDisplayMode) { _, newValue in
                        configManager.updateConfigValue(
                            key: "widgets.default.temperature.display-mode",
                            newValue: newValue
                        )
                    }

                    TextField("Label", text: $temperatureLabel)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: temperatureLabel) { _, newValue in
                            configManager.updateConfigValue(
                                key: "widgets.default.temperature.label",
                                newValue: newValue
                            )
                        }

                    StepperRow(
                        label: "Max text length",
                        value: $temperatureMaxLength,
                        range: 3...40,
                        suffix: " chars"
                    ) {
                        configManager.updateConfigValue(
                            key: "widgets.default.temperature.max-length",
                            newValue: String(temperatureMaxLength)
                        )
                    }
                }

                SettingsSection(title: "Fan") {
                    Picker("Display mode", selection: $fanDisplayMode) {
                        Text("Icon").tag("icon")
                        Text("Value").tag("value")
                        Text("Label + Value").tag("label-value")
                        Text("Icon + Value").tag("icon-value")
                        Text("Icon + Label + Value").tag("icon-label-value")
                        Text("Off").tag("off")
                    }
                    .pickerStyle(.menu)
                    .onChange(of: fanDisplayMode) { _, newValue in
                        configManager.updateConfigValue(
                            key: "widgets.default.fan.display-mode",
                            newValue: newValue
                        )
                    }

                    TextField("Label", text: $fanLabel)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: fanLabel) { _, newValue in
                            configManager.updateConfigValue(
                                key: "widgets.default.fan.label",
                                newValue: newValue
                            )
                        }

                    StepperRow(
                        label: "Max text length",
                        value: $fanMaxLength,
                        range: 3...40,
                        suffix: " chars"
                    ) {
                        configManager.updateConfigValue(
                            key: "widgets.default.fan.max-length",
                            newValue: String(fanMaxLength)
                        )
                    }
                }

                SettingsSection(title: "Energy") {
                    Picker("Display mode", selection: $energyDisplayMode) {
                        Text("Icon").tag("icon")
                        Text("Value").tag("value")
                        Text("Label + Value").tag("label-value")
                        Text("Icon + Value").tag("icon-value")
                        Text("Icon + Label + Value").tag("icon-label-value")
                        Text("Off").tag("off")
                    }
                    .pickerStyle(.menu)
                    .onChange(of: energyDisplayMode) { _, newValue in
                        configManager.updateConfigValue(
                            key: "widgets.default.energy.display-mode",
                            newValue: newValue
                        )
                    }

                    TextField("Label", text: $energyLabel)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: energyLabel) { _, newValue in
                            configManager.updateConfigValue(
                                key: "widgets.default.energy.label",
                                newValue: newValue
                            )
                        }

                    StepperRow(
                        label: "Max text length",
                        value: $energyMaxLength,
                        range: 3...40,
                        suffix: " chars"
                    ) {
                        configManager.updateConfigValue(
                            key: "widgets.default.energy.max-length",
                            newValue: String(energyMaxLength)
                        )
                    }
                }

                SettingsSection(title: "Battery Display") {
                    Picker("Display mode", selection: $batteryDisplayMode) {
                        Text("Icon").tag("icon")
                        Text("Value").tag("value")
                        Text("Label + Value").tag("label-value")
                        Text("Icon + Value").tag("icon-value")
                        Text("Icon + Label + Value").tag("icon-label-value")
                        Text("Off").tag("off")
                    }
                    .pickerStyle(.menu)
                    .onChange(of: batteryDisplayMode) { _, newValue in
                        configManager.updateConfigValue(
                            key: "widgets.default.battery.display-mode",
                            newValue: newValue
                        )
                    }

                    TextField("Label", text: $batteryLabel)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: batteryLabel) { _, newValue in
                            configManager.updateConfigValue(
                                key: "widgets.default.battery.label",
                                newValue: newValue
                            )
                        }

                    StepperRow(
                        label: "Max text length",
                        value: $batteryMaxLength,
                        range: 3...40,
                        suffix: " chars"
                    ) {
                        configManager.updateConfigValue(
                            key: "widgets.default.battery.max-length",
                            newValue: String(batteryMaxLength)
                        )
                    }
                }

                SettingsSection(title: "Bluetooth") {
                    Picker("Display mode", selection: $bluetoothDisplayMode) {
                        Text("Icon").tag("icon")
                        Text("Value").tag("value")
                        Text("Label + Value").tag("label-value")
                        Text("Icon + Value").tag("icon-value")
                        Text("Icon + Label + Value").tag("icon-label-value")
                        Text("Off").tag("off")
                    }
                    .pickerStyle(.menu)
                    .onChange(of: bluetoothDisplayMode) { _, newValue in
                        configManager.updateConfigValue(
                            key: "widgets.default.bluetooth.display-mode",
                            newValue: newValue
                        )
                    }

                    TextField("Label", text: $bluetoothLabel)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: bluetoothLabel) { _, newValue in
                            configManager.updateConfigValue(
                                key: "widgets.default.bluetooth.label",
                                newValue: newValue
                            )
                        }

                    StepperRow(
                        label: "Max text length",
                        value: $bluetoothMaxLength,
                        range: 3...40,
                        suffix: " chars"
                    ) {
                        configManager.updateConfigValue(
                            key: "widgets.default.bluetooth.max-length",
                            newValue: String(bluetoothMaxLength)
                        )
                    }
                }

                SettingsSection(title: "Brightness Display") {
                    Picker("Display mode", selection: $brightnessDisplayMode) {
                        Text("Icon").tag("icon")
                        Text("Value").tag("value")
                        Text("Label + Value").tag("label-value")
                        Text("Icon + Value").tag("icon-value")
                        Text("Icon + Label + Value").tag("icon-label-value")
                        Text("Off").tag("off")
                    }
                    .pickerStyle(.menu)
                    .onChange(of: brightnessDisplayMode) { _, newValue in
                        configManager.updateConfigValue(
                            key: "widgets.default.brightness.display-mode",
                            newValue: newValue
                        )
                    }

                    TextField("Label", text: $brightnessLabel)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: brightnessLabel) { _, newValue in
                            configManager.updateConfigValue(
                                key: "widgets.default.brightness.label",
                                newValue: newValue
                            )
                        }

                    StepperRow(
                        label: "Max text length",
                        value: $brightnessMaxLength,
                        range: 3...40,
                        suffix: " chars"
                    ) {
                        configManager.updateConfigValue(
                            key: "widgets.default.brightness.max-length",
                            newValue: String(brightnessMaxLength)
                        )
                    }
                }

                SettingsSection(title: "Network (WiFi)") {
                    Picker("Display mode", selection: $networkWifiDisplayMode) {
                        Text("Icon").tag("icon")
                        Text("Value").tag("value")
                        Text("Label + Value").tag("label-value")
                        Text("Icon + Value").tag("icon-value")
                        Text("Icon + Label + Value").tag("icon-label-value")
                        Text("Off").tag("off")
                    }
                    .pickerStyle(.menu)
                    .onChange(of: networkWifiDisplayMode) { _, newValue in
                        configManager.updateConfigValue(
                            key: "widgets.default.network.wifi-display-mode",
                            newValue: newValue
                        )
                    }

                    TextField("Label", text: $networkWifiLabel)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: networkWifiLabel) { _, newValue in
                            configManager.updateConfigValue(
                                key: "widgets.default.network.wifi-label",
                                newValue: newValue
                            )
                        }

                    StepperRow(
                        label: "Max text length",
                        value: $networkWifiMaxLength,
                        range: 3...40,
                        suffix: " chars"
                    ) {
                        configManager.updateConfigValue(
                            key: "widgets.default.network.wifi-max-length",
                            newValue: String(networkWifiMaxLength)
                        )
                    }
                }

                SettingsSection(title: "Network (Ethernet)") {
                    Picker("Display mode", selection: $networkEthDisplayMode) {
                        Text("Icon").tag("icon")
                        Text("Value").tag("value")
                        Text("Label + Value").tag("label-value")
                        Text("Icon + Value").tag("icon-value")
                        Text("Icon + Label + Value").tag("icon-label-value")
                        Text("Off").tag("off")
                    }
                    .pickerStyle(.menu)
                    .onChange(of: networkEthDisplayMode) { _, newValue in
                        configManager.updateConfigValue(
                            key: "widgets.default.network.eth-display-mode",
                            newValue: newValue
                        )
                    }

                    TextField("Label", text: $networkEthLabel)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: networkEthLabel) { _, newValue in
                            configManager.updateConfigValue(
                                key: "widgets.default.network.eth-label",
                                newValue: newValue
                            )
                        }

                    StepperRow(
                        label: "Max text length",
                        value: $networkEthMaxLength,
                        range: 3...40,
                        suffix: " chars"
                    ) {
                        configManager.updateConfigValue(
                            key: "widgets.default.network.eth-max-length",
                            newValue: String(networkEthMaxLength)
                        )
                    }
                }

                Text("Time and Spaces keep their own dedicated settings tabs. Any new configurable widget should get a section here instead of staying TOML-only.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(24)
        }
        .onAppear { syncAll() }
        .onReceive(configManager.$config) { _ in
            // Only sync per-widget settings — NOT the widget list.
            // The widget list is owned by this tab's local state and written
            // back to config on every change. Re-syncing it from onReceive
            // causes a feedback loop (local change → file write → file watcher
            // reload → onReceive overwrites local state with stale config).
            syncWidgetSettings()
        }
    }

    // MARK: - Sync

    private func syncAll() {
        syncWidgetList()
        syncWidgetSettings()
    }

    private func syncWidgetList() {
        activeWidgets = (configManager.config.rootToml.widgets?.displayed ?? [])
            .map { IdentifiedWidget(item: $0) }
    }

    private func syncWidgetSettings() {
        let batteryConfig = configManager.globalWidgetConfig(for: "default.battery")
        batteryShowPercentage = batteryConfig["show-percentage"]?.boolValue ?? true
        batteryWarningLevel = batteryConfig["warning-level"]?.intValue ?? 30
        batteryCriticalLevel = batteryConfig["critical-level"]?.intValue ?? 10

        let volumeConfig = configManager.globalWidgetConfig(for: "default.volume")
        volumeShowPercentage = volumeConfig["show-percentage"]?.boolValue ?? false
        volumeScrollStep = volumeConfig["scroll-step"]?.doubleValue ?? 3

        let brightnessConfig = configManager.globalWidgetConfig(for: "default.brightness")
        brightnessShowPercentage = brightnessConfig["show-percentage"]?.boolValue ?? false
        brightnessScrollStep = brightnessConfig["scroll-step"]?.doubleValue ?? 3

        let weatherConfig = configManager.globalWidgetConfig(for: "default.weather")
        weatherProvider = weatherConfig["provider"]?.stringValue ?? "met-no"
        weatherUseIPFallback = weatherConfig["use-ip-fallback"]?.boolValue ?? true

        let weatherLocationConfig = weatherConfig["location"]?.dictionaryValue ?? [:]
        weatherUsesManualLocation =
            weatherLocationConfig["latitude"]?.doubleValue != nil
            && weatherLocationConfig["longitude"]?.doubleValue != nil
        weatherLocationName = weatherLocationConfig["name"]?.stringValue ?? ""
        weatherLatitude = decimalString(from: weatherLocationConfig["latitude"]?.doubleValue)
        weatherLongitude = decimalString(from: weatherLocationConfig["longitude"]?.doubleValue)

        let nowPlayingConfig = configManager.globalWidgetConfig(for: "default.nowplaying")
        nowPlayingShowIcon = nowPlayingConfig["show-icon"]?.boolValue ?? true
        nowPlayingShowTitle = nowPlayingConfig["show-title"]?.boolValue ?? true
        nowPlayingShowArtist = nowPlayingConfig["show-artist"]?.boolValue ?? false
        nowPlayingShowAlbum = nowPlayingConfig["show-album"]?.boolValue ?? false
        nowPlayingTitleMaxLength = nowPlayingConfig["title-max-length"]?.intValue ?? 30
        nowPlayingArtistMaxLength = nowPlayingConfig["artist-max-length"]?.intValue ?? 20
        nowPlayingAlbumMaxLength = nowPlayingConfig["album-max-length"]?.intValue ?? 20
        nowPlayingSeparator = nowPlayingConfig["separator"]?.stringValue ?? " - "
        nowPlayingShowVisualizer = nowPlayingConfig["show-visualizer"]?.boolValue ?? true
        nowPlayingVisualizerPosition = nowPlayingConfig["visualizer-position"]?.stringValue ?? "right"

        // Volume display mode settings
        let volumeConfig2 = configManager.globalWidgetConfig(for: "default.volume")
        volumeDisplayMode = volumeConfig2["display-mode"]?.stringValue ?? "icon-value"
        volumeLabel = volumeConfig2["label"]?.stringValue ?? ""
        volumeMaxLength = volumeConfig2["max-length"]?.intValue ?? 10

        // System Monitor CPU settings
        let systemMonitorConfig = configManager.globalWidgetConfig(for: "default.systemmonitor")
        systemMonitorCpuDisplayMode = systemMonitorConfig["cpu-display-mode"]?.stringValue ?? "icon-value"
        systemMonitorCpuLabel = systemMonitorConfig["cpu-label"]?.stringValue ?? ""
        systemMonitorCpuMaxLength = systemMonitorConfig["cpu-max-length"]?.intValue ?? 10

        // System Monitor Memory settings
        systemMonitorMemDisplayMode = systemMonitorConfig["mem-display-mode"]?.stringValue ?? "icon-value"
        systemMonitorMemLabel = systemMonitorConfig["mem-label"]?.stringValue ?? ""
        systemMonitorMemMaxLength = systemMonitorConfig["mem-max-length"]?.intValue ?? 10

        // Temperature settings
        let temperatureConfig = configManager.globalWidgetConfig(for: "default.temperature")
        temperatureDisplayMode = temperatureConfig["display-mode"]?.stringValue ?? "icon-value"
        temperatureLabel = temperatureConfig["label"]?.stringValue ?? ""
        temperatureMaxLength = temperatureConfig["max-length"]?.intValue ?? 10

        // Fan settings
        let fanConfig = configManager.globalWidgetConfig(for: "default.fan")
        fanDisplayMode = fanConfig["display-mode"]?.stringValue ?? "icon-value"
        fanLabel = fanConfig["label"]?.stringValue ?? ""
        fanMaxLength = fanConfig["max-length"]?.intValue ?? 10

        // Energy settings
        let energyConfig = configManager.globalWidgetConfig(for: "default.energy")
        energyDisplayMode = energyConfig["display-mode"]?.stringValue ?? "icon-value"
        energyLabel = energyConfig["label"]?.stringValue ?? ""
        energyMaxLength = energyConfig["max-length"]?.intValue ?? 10

        // Battery display mode settings
        let batteryConfig2 = configManager.globalWidgetConfig(for: "default.battery")
        batteryDisplayMode = batteryConfig2["display-mode"]?.stringValue ?? "icon-value"
        batteryLabel = batteryConfig2["label"]?.stringValue ?? ""
        batteryMaxLength = batteryConfig2["max-length"]?.intValue ?? 10

        // Bluetooth settings
        let bluetoothConfig = configManager.globalWidgetConfig(for: "default.bluetooth")
        bluetoothDisplayMode = bluetoothConfig["display-mode"]?.stringValue ?? "icon-value"
        bluetoothLabel = bluetoothConfig["label"]?.stringValue ?? ""
        bluetoothMaxLength = bluetoothConfig["max-length"]?.intValue ?? 10

        // Brightness display mode settings
        let brightnessConfig2 = configManager.globalWidgetConfig(for: "default.brightness")
        brightnessDisplayMode = brightnessConfig2["display-mode"]?.stringValue ?? "icon-value"
        brightnessLabel = brightnessConfig2["label"]?.stringValue ?? ""
        brightnessMaxLength = brightnessConfig2["max-length"]?.intValue ?? 10

        // Network WiFi/Ethernet settings
        let networkConfig = configManager.globalWidgetConfig(for: "default.network")
        networkWifiDisplayMode = networkConfig["wifi-display-mode"]?.stringValue ?? "icon-value"
        networkWifiLabel = networkConfig["wifi-label"]?.stringValue ?? ""
        networkWifiMaxLength = networkConfig["wifi-max-length"]?.intValue ?? 10
        networkEthDisplayMode = networkConfig["eth-display-mode"]?.stringValue ?? "icon-value"
        networkEthLabel = networkConfig["eth-label"]?.stringValue ?? ""
        networkEthMaxLength = networkConfig["eth-max-length"]?.intValue ?? 10
    }

    // MARK: - Widget list operations

    private func labelFor(_ id: String) -> String {
        allAvailableWidgets.first(where: { $0.id == id })?.label ?? id
    }

    private func iconFor(_ id: String) -> String {
        allAvailableWidgets.first(where: { $0.id == id })?.icon ?? "questionmark"
    }

    private func removeWidget(_ widget: IdentifiedWidget) {
        withAnimation(.easeInOut(duration: 0.2)) {
            activeWidgets.removeAll(where: { $0.id == widget.id })
        }
        writeWidgetList()
    }

    private func addWidget(_ id: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            activeWidgets.append(IdentifiedWidget(item: TomlWidgetItem(id: id, inlineParams: [:])))
        }
        writeWidgetList()
    }

    private func moveWidget(_ widget: IdentifiedWidget, direction: Int) {
        guard let index = activeWidgets.firstIndex(where: { $0.id == widget.id }) else { return }
        let newIndex = index + direction
        guard newIndex >= 0, newIndex < activeWidgets.count else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            activeWidgets.swapAt(index, newIndex)
        }
        writeWidgetList()
    }

    private func writeWidgetList() {
        let listItems = activeWidgets
            .map { "    \(serializeWidgetItem($0.item))" }
            .joined(separator: ",\n")
        let listString = listItems.isEmpty ? "[]" : "[\n\(listItems)\n]"
        configManager.updateConfigValue(
            key: "widgets.displayed",
            newValue: listString)
    }

    // MARK: - TOML serialization

    private func serializeWidgetItem(_ item: TomlWidgetItem) -> String {
        if item.inlineParams.isEmpty {
            return quote(item.id)
        }

        return "{ \(serializeKey(item.id)) = \(serializeInlineTable(item.inlineParams)) }"
    }

    private func serializeInlineTable(_ dict: ConfigData) -> String {
        let pairs = dict.keys.sorted().map { key in
            "\(serializeKey(key)) = \(serializeTOMLValue(dict[key] ?? .null))"
        }
        return "{ \(pairs.joined(separator: ", ")) }"
    }

    private func serializeTOMLValue(_ value: TOMLValue) -> String {
        switch value {
        case .string(let string):
            return quote(string)
        case .bool(let bool):
            return bool ? "true" : "false"
        case .int(let int):
            return String(int)
        case .double(let double):
            return String(double)
        case .array(let array):
            return "[\(array.map(serializeTOMLValue).joined(separator: ", "))]"
        case .dictionary(let dict):
            return serializeInlineTable(dict)
        case .null:
            return quote("")
        }
    }

    private func quote(_ string: String) -> String {
        let escaped = string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    private func serializeKey(_ key: String) -> String {
        let bareKeyPattern = #"^[A-Za-z0-9_-]+$"#
        if key.range(of: bareKeyPattern, options: .regularExpression) != nil {
            return key
        }
        return quote(key)
    }

    // MARK: - Battery thresholds

    private enum BatteryThresholdChange {
        case warning
        case critical
    }

    private func clampBatteryThresholds(changed: BatteryThresholdChange) {
        switch changed {
        case .warning:
            if batteryWarningLevel <= batteryCriticalLevel {
                batteryCriticalLevel = max(1, batteryWarningLevel - 5)
            }
        case .critical:
            if batteryCriticalLevel >= batteryWarningLevel {
                batteryWarningLevel = min(80, batteryCriticalLevel + 5)
            }
        }

        configManager.updateConfigValues(pairs: [
            (key: "widgets.default.battery.warning-level", value: String(batteryWarningLevel)),
            (key: "widgets.default.battery.critical-level", value: String(batteryCriticalLevel)),
        ])
    }

    // MARK: - Weather manual location

    private var parsedWeatherLatitude: Double? {
        parseDecimal(weatherLatitude)
    }

    private var parsedWeatherLongitude: Double? {
        parseDecimal(weatherLongitude)
    }

    private func commitWeatherManualLocation() {
        guard let latitude = parsedWeatherLatitude, let longitude = parsedWeatherLongitude else { return }

        configManager.updateConfigValues(pairs: [
            (
                key: "widgets.default.weather.location.latitude",
                value: String(format: "%.4f", latitude)
            ),
            (
                key: "widgets.default.weather.location.longitude",
                value: String(format: "%.4f", longitude)
            ),
        ])

        let trimmedName = weatherLocationName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            configManager.removeConfigValue(key: "widgets.default.weather.location.name")
        } else {
            configManager.updateConfigValue(
                key: "widgets.default.weather.location.name",
                newValue: trimmedName
            )
        }
    }

    private func clearWeatherManualLocation() {
        configManager.removeConfigValues(keys: [
            "widgets.default.weather.location.latitude",
            "widgets.default.weather.location.longitude",
            "widgets.default.weather.location.name",
        ])
    }

    private func parseDecimal(_ text: String) -> Double? {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard !normalized.isEmpty else { return nil }
        return Double(normalized)
    }

    private func decimalString(from value: Double?) -> String {
        guard let value else { return "" }
        return String(format: "%.4f", value)
    }
}

// MARK: - Drop Delegate (stable identity based)

private struct WidgetDropDelegate: DropDelegate {
    let targetItem: IdentifiedWidget
    @Binding var activeWidgets: [IdentifiedWidget]
    @Binding var draggedItem: IdentifiedWidget?
    let onDrop: () -> Void

    func dropEntered(info: DropInfo) {
        guard let dragged = draggedItem,
              dragged.id != targetItem.id,
              let fromIndex = activeWidgets.firstIndex(where: { $0.id == dragged.id }),
              let toIndex = activeWidgets.firstIndex(where: { $0.id == targetItem.id })
        else { return }

        withAnimation(.easeInOut(duration: 0.15)) {
            activeWidgets.move(
                fromOffsets: IndexSet(integer: fromIndex),
                toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        onDrop()
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

// MARK: - Stepper Row

private struct StepperRow: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let suffix: String
    let onCommit: () -> Void

    var body: some View {
        HStack {
            Text(label)
                .frame(width: 130, alignment: .leading)
            Stepper(value: $value, in: range) {
                Text("\(value)\(suffix)")
                    .monospacedDigit()
            }
            .onChange(of: value) { _, _ in
                onCommit()
            }
            Spacer()
        }
    }
}
