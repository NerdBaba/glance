import EventKit
import SwiftUI

struct TimeWidget: View {
    @ObservedObject var configProvider: ConfigProvider
    @StateObject private var calendarManager: CalendarManager
    @StateObject private var timeProvider = TimeProvider()
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

    @State private var rect = CGRect()

    init(configProvider: ConfigProvider) {
        self.configProvider = configProvider
        _calendarManager = StateObject(
            wrappedValue: CalendarManager(configProvider: configProvider)
        )
    }

    @Environment(\.appearance) var appearance
    @Environment(\.widgetFont) var widgetFont

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(timeProvider.formattedTime(pattern: format, timeZone: timeZone))
                .fontWeight(.semibold)
                .font(widgetFont.toFont())
            if let event = calendarManager.nextEvent, calendarShowEvents {
                Text(eventText(for: event))
                    .opacity(0.8)
                    .font(.subheadline)
            }
        }
        .font(widgetFont.toFont())
        .fixedSize(horizontal: true, vertical: false)
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        rect = geometry.frame(in: .global)
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

    // Create text for the calendar event.
    private func eventText(for event: EKEvent) -> String {
        var text = event.title ?? ""
        if !event.isAllDay {
            text += " ("
            text += timeProvider.format(pattern: calendarFormat, date: event.startDate, timeZone: timeZone)
            text += ")"
        }
        return text
    }
}

/// Background timer + time formatting — keeps timer work off main thread.
class TimeProvider: ObservableObject {
    @Published var formattedTime: String = ""

    private var timer: Timer?
    private var formatter = DateFormatter()
    private var lastPattern: String = ""
    private var lastTimeZone: String?
    private let timerQueue = DispatchQueue(label: "com.glance.timeprovider", qos: .utility)

    init() {
        updateFormattedTime()
        timerQueue.async { [weak self] in
            self?.startTimer()
            RunLoop.current.run()
        }
    }

    deinit {
        timer?.invalidate()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateFormattedTime()
        }
        timer?.tolerance = 0.1
    }

    private func updateFormattedTime() {
        let now = Date()
        let text = format(pattern: "E d, J:mm", date: now, timeZone: nil)
        DispatchQueue.main.async { [weak self] in
            self?.formattedTime = text
        }
    }

    func format(pattern: String, date: Date, timeZone: String?) -> String {
        if pattern != lastPattern || timeZone != lastTimeZone {
            formatter = DateFormatter()
            formatter.dateFormat = pattern
            if let timeZone = timeZone, let tz = TimeZone(identifier: timeZone) {
                formatter.timeZone = tz
            } else {
                formatter.timeZone = TimeZone.current
            }
            lastPattern = pattern
            lastTimeZone = timeZone
        }
        return formatter.string(from: date)
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
