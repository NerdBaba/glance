import SwiftUI

struct EnergyWidget: View {
    @EnvironmentObject var configProvider: ConfigProvider
    @Environment(\.widgetFont) var widgetFont
    @ObservedObject private var energyManager = EnergyManager.shared
    @State private var rect: CGRect = .zero

    private var config: ConfigData { configProvider.config }
    private var mode: String { config["mode"]?.stringValue ?? "current" } // "current" or "total"

    private var displayMode: String { config["display-mode"]?.stringValue ?? "icon-value" }
    private var label: String { config["label"]?.stringValue ?? "" }
    private var maxLength: Int { config["max-length"]?.intValue ?? 10 }

    private var valueText: String {
        let raw: String = {
            switch mode {
            case "total":
                let kwh = energyManager.totalEnergy
                if kwh >= 1.0 {
                    return String(format: "%.2f kWh", kwh)
                } else {
                    return String(format: "%.0f Wh", kwh * 1000)
                }
            default:
                if energyManager.currentPower >= 1000 {
                    return String(format: "%.1f kW", energyManager.currentPower / 1000.0)
                } else {
                    return String(format: "%.0f W", energyManager.currentPower)
                }
            }
        }()
        let limit = max(maxLength, 3)
        if raw.count > limit {
            let truncated = raw.prefix(limit - 3)
            return truncated + "..."
        }
        return raw
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
                Image(systemName: "bolt.fill")
                    .barStatusSymbol(size: 12, opticalYOffset: -0.1)
            case "value":
                Text(valueText)
                    .font(widgetFont.toFont())
                    .monospacedDigit()
                    .fixedSize(horizontal: true, vertical: false)
            case "label-value":
                Text("\(label) \(valueText)")
                    .font(widgetFont.toFont())
                    .monospacedDigit()
                    .fixedSize(horizontal: true, vertical: false)
            case "icon-label-value":
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
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
                    Image(systemName: "bolt.fill")
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
            MenuBarPopup.show(rect: rect, id: "energy") {
                EnergyPopup(energyManager: energyManager)
            }
        }
        .animation(.smooth(duration: 0.3), value: energyManager.currentPower)
    }
}

struct EnergyWidget_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            EnergyWidget()
        }
        .frame(width: 200, height: 100)
        .background(Color.black)
        .environmentObject(ConfigProvider(config: [:]))
    }
}
