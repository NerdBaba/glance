import SwiftUI

struct TemperatureWidget: View {
    @EnvironmentObject var configProvider: ConfigProvider
    @Environment(\.widgetFont) var widgetFont
    @ObservedObject private var thermalManager = ThermalManager.shared
    @State private var rect: CGRect = .zero

    private var config: ConfigData { configProvider.config }
    private var showUnit: Bool { config["show-unit"]?.boolValue ?? true }
    private var sensor: String { config["sensor"]?.stringValue ?? "cpu" }
    private var displayMode: String { config["display-mode"]?.stringValue ?? "icon-value" }
    private var label: String { config["label"]?.stringValue ?? "" }
    private var maxLength: Int { config["max-length"]?.intValue ?? 10 }

    private var displayTemp: Double {
        thermalManager.cpuTemperature
    }

    private var valueText: String {
        if showUnit {
            return "\(Int(round(displayTemp)))\u{00b0}C"
        } else {
            return "\(Int(round(displayTemp)))"
        }
    }

    private var displayText: String {
        let full = label.isEmpty ? valueText : label + " " + valueText
        if full.count > maxLength, maxLength > 3 {
            return String(full.prefix(maxLength - 3)) + "..."
        }
        return full
    }

    var body: some View {
        Group {
            switch displayMode {
            case "icon":
                Image(systemName: "thermometer")
                    .barStatusSymbol(size: 12, opticalYOffset: -0.1)
            case "value":
                Text(valueText)
                    .font(widgetFont.toFont())
                    .monospacedDigit()
                    .fixedSize(horizontal: true, vertical: false)
            case "label-value":
                Text(displayText)
                    .font(widgetFont.toFont())
                    .monospacedDigit()
                    .fixedSize(horizontal: true, vertical: false)
            case "icon-label-value":
                HStack(spacing: 6) {
                    Image(systemName: "thermometer")
                        .barStatusSymbol(size: 12, opticalYOffset: -0.1)
                    Text(displayText)
                        .font(widgetFont.toFont())
                        .monospacedDigit()
                        .fixedSize(horizontal: true, vertical: false)
                }
            case "off":
                EmptyView()
            default: // "icon-value"
                HStack(spacing: 6) {
                    Image(systemName: "thermometer")
                        .barStatusSymbol(size: 12, opticalYOffset: -0.1)
                    Text(valueText)
                        .font(widgetFont.toFont())
                        .monospacedDigit()
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
        }
        .barSingleLineAligned()
        .experimentalConfiguration(horizontalPadding: 10)
        .frame(maxHeight: .infinity)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { rect = geo.frame(in: .global) }
            }
        )
        .background(.black.opacity(0.001))
        .onTapGesture {
            MenuBarPopup.show(rect: rect, id: "temperature") {
                TemperaturePopup(thermalManager: thermalManager)
            }
        }
        .animation(.smooth(duration: 0.3), value: thermalManager.cpuTemperature)
    }
}

struct TemperatureWidget_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            TemperatureWidget()
        }
        .frame(width: 200, height: 100)
        .background(Color.black)
        .environmentObject(ConfigProvider(config: [:]))
    }
}
