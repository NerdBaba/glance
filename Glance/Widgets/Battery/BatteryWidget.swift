import SwiftUI

struct BatteryWidget: View {
    @EnvironmentObject var configProvider: ConfigProvider
    var config: ConfigData { configProvider.config }
    var showPercentage: Bool { config["show-percentage"]?.boolValue ?? true }
    var warningLevel: Int { config["warning-level"]?.intValue ?? 20 }
    var criticalLevel: Int { config["critical-level"]?.intValue ?? 10 }
    var displayMode: String { config["display-mode"]?.stringValue ?? "icon-value" }
    var label: String { config["label"]?.stringValue ?? "" }
    var maxLength: Int { config["max-length"]?.intValue ?? 10 }

    @ObservedObject private var batteryManager = BatteryManager.shared
    private var level: Int { batteryManager.batteryLevel }
    private var isCharging: Bool { batteryManager.isCharging }
    private var isPluggedIn: Bool { batteryManager.isPluggedIn }

    @State private var rect: CGRect = CGRect()

    @Environment(\.widgetFont) var widgetFont

    var body: some View {
        Group {
            switch displayMode {
            case "icon":
                iconView
            case "value":
                valueView
            case "label-value":
                textView
            case "icon-label-value":
                iconLabelView
            case "off":
                EmptyView()
            default: // "icon-value"
                bothView
            }
        }
        .barSingleLineAligned(opticalYOffset: -0.1)
        .experimentalConfiguration()
        .frame(maxHeight: .infinity)
        .background(.black.opacity(0.001))
        .onTapGesture {
            MenuBarPopup.show(rect: rect, id: "battery") {
                BatteryPopup(configProvider: configProvider)
            }
        }
    }

    // MARK: - Display Modes

    /// Battery shape icon (current behavior - already shows level inside)
    private var iconView: some View {
        ZStack(alignment: .leading) {
            BatteryBodyView(mask: false)
                .opacity(showPercentage ? 0.3 : 0.4)
            BatteryBodyView(mask: true)
                .clipShape(
                    Rectangle().path(
                        in: CGRect(
                            x: showPercentage ? 0 : 2,
                            y: 0,
                            width: 30 * Int(level)
                                / (showPercentage ? 110 : 130),
                            height: 10
                        )
                    )
                )
                .foregroundStyle(batteryColor)
            BatteryText(
                level: level, isCharging: isCharging,
                isPluggedIn: isPluggedIn, showPercentage: showPercentage
            )
            .foregroundStyle(batteryTextColor)
        }
        .frame(width: 30, height: 10)
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        rect = geometry.frame(in: .global)
                    }
            }
        )
    }

    /// Value only: level number + charging icon
    private var valueView: some View {
        HStack(alignment: .center, spacing: 2) {
            Text("\(level)")
                .font(widgetFont.toFont())
                .monospacedDigit()
                .fontWeight(.semibold)
            if isCharging && level != 100 {
                Image(systemName: "bolt.fill")
                    .font(widgetFont.toFont())
            }
            if !isCharging && isPluggedIn && level != 100 {
                Image(systemName: "powerplug.portrait.fill")
                    .font(widgetFont.toFont())
            }
        }
        .foregroundStyle(batteryTextColor)
        .transition(.blurReplace)
        .animation(.smooth, value: isCharging)
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        rect = geometry.frame(in: .global)
                    }
            }
        )
    }

    /// Label + value: level number + charging icon (no battery shape)
    private var textView: some View {
        HStack(alignment: .center, spacing: 2) {
            let displayLabel = label.isEmpty ? "\(level)" : label
            let truncatedLabel = displayLabel.count > maxLength
                ? String(displayLabel.prefix(maxLength - 3)) + "..."
                : displayLabel
            Text(truncatedLabel)
                .font(widgetFont.toFont())
                .monospacedDigit()
                .fontWeight(.semibold)
            if isCharging && level != 100 {
                Image(systemName: "bolt.fill")
                    .font(widgetFont.toFont())
            }
            if !isCharging && isPluggedIn && level != 100 {
                Image(systemName: "powerplug.portrait.fill")
                    .font(widgetFont.toFont())
            }
        }
        .foregroundStyle(batteryTextColor)
        .transition(.blurReplace)
        .animation(.smooth, value: isCharging)
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        rect = geometry.frame(in: .global)
                    }
            }
        )
    }

    /// Icon + label text
    private var iconLabelView: some View {
        HStack(alignment: .center, spacing: 3) {
            ZStack(alignment: .leading) {
                BatteryBodyView(mask: false)
                    .opacity(showPercentage ? 0.3 : 0.4)
                BatteryBodyView(mask: true)
                    .clipShape(
                        Rectangle().path(
                            in: CGRect(
                                x: showPercentage ? 0 : 2,
                                y: 0,
                                width: 30 * Int(level)
                                    / (showPercentage ? 110 : 130),
                                height: 10
                            )
                        )
                    )
                    .foregroundStyle(batteryColor)
                BatteryText(
                    level: level, isCharging: isCharging,
                    isPluggedIn: isPluggedIn, showPercentage: showPercentage
                )
                .foregroundStyle(batteryTextColor)
            }
            .frame(width: 30, height: 10)

            let displayLabel = label.isEmpty ? "\(level)" : label
            let truncatedLabel = displayLabel.count > maxLength
                ? String(displayLabel.prefix(maxLength - 3)) + "..."
                : displayLabel
            Text(truncatedLabel)
                .font(widgetFont.toFont())
                .fontWeight(.semibold)
                .foregroundStyle(batteryTextColor)
        }
        .transition(.blurReplace)
        .animation(.smooth, value: isCharging)
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        rect = geometry.frame(in: .global)
                    }
            }
        )
    }

    /// Icon + label (legacy "both" behavior)
    private var bothView: some View {
        HStack(alignment: .center, spacing: 3) {
            ZStack(alignment: .leading) {
                BatteryBodyView(mask: false)
                    .opacity(showPercentage ? 0.3 : 0.4)
                BatteryBodyView(mask: true)
                    .clipShape(
                        Rectangle().path(
                            in: CGRect(
                                x: showPercentage ? 0 : 2,
                                y: 0,
                                width: 30 * Int(level)
                                    / (showPercentage ? 110 : 130),
                                height: 10
                            )
                        )
                    )
                    .foregroundStyle(batteryColor)
                BatteryText(
                    level: level, isCharging: isCharging,
                    isPluggedIn: isPluggedIn, showPercentage: showPercentage
                )
                .foregroundStyle(batteryTextColor)
            }
            .frame(width: 30, height: 10)

            Text(label)
                .font(widgetFont.toFont())
                .fontWeight(.semibold)
                .foregroundStyle(batteryTextColor)
        }
        .transition(.blurReplace)
        .animation(.smooth, value: isCharging)
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        rect = geometry.frame(in: .global)
                    }
            }
        )
    }

    // MARK: - Colors

    private var batteryTextColor: Color {
        if isCharging {
            return .foregroundOutsideInvert
        } else {
            return level > warningLevel ? .foregroundOutsideInvert : .black
        }
    }

    private var batteryColor: Color {
        if isCharging {
            return .green
        } else {
            if level <= criticalLevel {
                return .red
            } else if level <= warningLevel {
                return .yellow
            } else {
                return .icon
            }
        }
    }
}

private struct BatteryText: View {
    @Environment(\.widgetFont) var widgetFont

    let level: Int
    let isCharging: Bool
    let isPluggedIn: Bool
    let showPercentage: Bool

    var body: some View {
        HStack(alignment: .center, spacing: -1) {
            if showPercentage {
                Text("\(level)")
                    .font(widgetFont.toFont())
                    .monospacedDigit()
                    .transition(.blurReplace)
            }

            if isCharging && level != 100 {
                Image(systemName: "bolt.fill")
                    .font(widgetFont.toFont())
            }

            if !isCharging && isPluggedIn && level != 100 {
                Image(systemName: "powerplug.portrait.fill")
                    .font(widgetFont.toFont())
                    .padding(.leading, 1)
            }
        }
        .foregroundStyle(
            showPercentage ? .foregroundOutsideInvert : .foregroundOutside
        )
        .fontWeight(.semibold)
        .transition(.blurReplace)
        .animation(.smooth, value: isCharging)
        .frame(width: 26, height: 15)
    }
}

private struct BatteryBodyView: View {
    let mask: Bool

    @EnvironmentObject var configProvider: ConfigProvider
    var config: ConfigData { configProvider.config }
    var showPercentage: Bool { config["show-percentage"]?.boolValue ?? true }

    var body: some View {
        ZStack {
            if showPercentage || !mask {
                Image(systemName: "battery.0")
                    .resizable()
                    .scaledToFit()
            }
            if showPercentage || mask {
                Rectangle()
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                    .padding(.horizontal, showPercentage ? 3 : 4.4)
                    .padding(.vertical, showPercentage ? 2 : 3.5)
                    .offset(
                        x: showPercentage ? -2 : -1.77,
                        y: showPercentage ? 0 : 0.2)
            }
        }
        .compositingGroup()
    }
}

struct BatteryWidget_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            BatteryWidget()
        }.frame(width: 200, height: 100)
            .background(.yellow)
            .environmentObject(ConfigProvider(config: [:]))
    }
}
