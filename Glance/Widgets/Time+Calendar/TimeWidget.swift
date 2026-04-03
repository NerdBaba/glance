import EventKit
import SwiftUI

struct TimeWidget: View {
    @ObservedObject var configProvider: ConfigProvider
    @StateObject private var calendarManager: CalendarManager
    var config: ConfigData { configProvider.config }
    var calendarConfig: ConfigData? { config["calendar"]?.dictionaryValue }

    var format: String { config["format"]?.stringValue ?? "E d, J:mm" }
    var timeZone: String? { config["time-zone"]?.stringValue }

    var calendarFormat: String {
        calendarConfig?["format"]?.stringValue ?? "J:mm"
    }
    var calendarShowEvents: Bool {
        calendarConfig?["show-events"]?.boolValue ?? true
    }

    @State private var currentTime = Date()
    @State private var rect = CGRect()
    @State private var cachedFormatter = DateFormatter()
    @State private var cachedFormat: String = ""
    @State private var cachedTimeZoneId: String?

    private let timer = Timer.publish(every: 1, on: .main, in: .common)
        .autoconnect()

    init(configProvider: ConfigProvider) {
        self.configProvider = configProvider
        _calendarManager = StateObject(
            wrappedValue: CalendarManager(configProvider: configProvider)
        )
    }

    @Environment(\.appearance) var appearance
    @Environment(\.barFont) var barFont
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(formattedTime(pattern: format, from: currentTime))
                .fontWeight(.semibold)
                .font(barFont.toFont())
            if let event = calendarManager.nextEvent, calendarShowEvents {
                Text(eventText(for: event))
                    .opacity(0.8)
                    .font(.subheadline)
            }
        }
        .font(barFont.toFont())
        .shadow(color: .black.opacity(0.3), radius: 3)
        .onReceive(timer) { date in
            currentTime = date
        }
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        rect = geometry.frame(in: .global)
                    }
                    .onChange(of: geometry.frame(in: .global)) {
                        oldState, newState in
                        rect = newState
                    }
            }
        )
        .experimentalConfiguration()
        .frame(maxHeight: .infinity)
        .background(.black.opacity(0.001))
        .monospacedDigit()
        .onTapGesture {
            MenuBarPopup.show(rect: rect, id: "calendar") {
                CalendarPopup(
                    calendarManager: calendarManager,
                    configProvider: configProvider)
            }
        }
    }

    // Format the current time — reuses cached DateFormatter when format/timezone haven't changed.
    private func formattedTime(pattern: String, from time: Date) -> String {
        if pattern != cachedFormat || timeZone != cachedTimeZoneId {
            cachedFormatter = DateFormatter()
            cachedFormatter.dateFormat = pattern
            if let timeZone = timeZone,
               let tz = TimeZone(identifier: timeZone) {
                cachedFormatter.timeZone = tz
            } else {
                cachedFormatter.timeZone = TimeZone.current
            }
            cachedFormat = pattern
            cachedTimeZoneId = timeZone
        }
        return cachedFormatter.string(from: time)
    }

    // Create text for the calendar event.
    private func eventText(for event: EKEvent) -> String {
        var text = event.title ?? ""
        if !event.isAllDay {
            text += " ("
            text += formattedTime(
                pattern: calendarFormat, from: event.startDate)
            text += ")"
        }
        return text
    }
}

struct TimeWidget_Previews: PreviewProvider {
    static var previews: some View {
        let provider = ConfigProvider(config: ConfigData())

        ZStack {
            TimeWidget(configProvider: provider)
        }.frame(width: 500, height: 100)
    }
}
