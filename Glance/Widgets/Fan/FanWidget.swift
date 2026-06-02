import SwiftUI

struct FanWidget: View {
    @EnvironmentObject var configProvider: ConfigProvider
    @Environment(\.widgetFont) var widgetFont
    @ObservedObject private var thermalManager = ThermalManager.shared
    @State private var rect: CGRect = .zero

    private var config: ConfigData { configProvider.config }
    private var showPercentage: Bool { config["show-percentage"]?.boolValue ?? false }
    private var displayMode: String { config["display-mode"]?.stringValue ?? "icon-value" }
    private var label: String { config["label"]?.stringValue ?? "" }
    private var maxLength: Int { config["max-length"]?.intValue ?? 10 }

    private var valueText: String {
        if showPercentage {
            let percent = min(100, Int((Double(thermalManager.fanSpeed) / 3000.0) * 100))
            return "\(percent)%"
        } else {
            return "\(thermalManager.fanSpeed)"
        }
    }

    private var displayText: String {
        let full = label.isEmpty ? valueText : label + " " + valueText
        if full.count > maxLength, maxLength > 3 {
            return String(full.prefix(maxLength - 3)) + "..."
        }
        return full
    }

    @ViewBuilder
    var body: some View {
        Group {
            switch displayMode {
            case "icon":
                Image(systemName: "fan")
                    .barStatusSymbol(size: 12, opticalYOffset: -0.1)
            case "value":
                Text(valueText)
                    .font(widgetFont.toFont())
                    .monospacedDigit()
                    .fixedSize(horizontal: true, vertical: false)
            case "icon-label-value":
                HStack(spacing: 6) {
                    Image(systemName: "fan")
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
                    Image(systemName: "fan")
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
            MenuBarPopup.show(rect: rect, id: "fan") {
                FanPopup(thermalManager: thermalManager)
            }
        }
        .animation(.smooth(duration: 0.3), value: thermalManager.fanSpeed)
    }
}

struct FanWidget_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            FanWidget()
        }
        .frame(width: 200, height: 100)
        .background(Color.black)
        .environmentObject(ConfigProvider(config: [:]))
    }
}
