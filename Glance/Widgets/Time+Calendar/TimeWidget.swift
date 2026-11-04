import EventKit
import SwiftUI

struct TimeWidget: View {
    @ObservedObject var configProvider: ConfigProvider
    @StateObject private var calendarManager: CalendarManager
    @StateObject private var timeProvider = TimeProvider()
    var config: ConfigData { configProvider.config }
    var calendarConfig: ConfigData? { config["calendar"]?.dictionaryValue }

    var format: String { config["format"]?.stringValue ?? "E d, H:mm" }
    var timeZone: String? { config["time-zone"]?.stringValue }

    var calendarFormat: String {
        calendarConfig?["format"]?.stringValue ?? "H:mm"
    }
    var calendarShowEvents: Bool {
        calendarConfig?["show-events"]?.boolValue ?? true
    }

    @State private var rect = CGRect()

    init(configProvider: ConfigProvider) {
        self.configProvider = configProvider
        _calendarManager = StateObject(
            wrappedValue: CalendarManager(
                configProvider: configProvider,
                previewMode: Self.isPreviewRender
            )
        )
    }

    private static var isPreviewRender: Bool {
        ProcessInfo.processInfo.environment["GLANCE_PREVIEW_BAR_PATH"] != nil
            || CommandLine.arguments.contains("--export-bar")
            || CommandLine.arguments.contains("--preview-panel")
    }

    @Environment(\.appearance) var appearance
    @Environment(\.widgetFont) var widgetFont

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            HStack(spacing: config["content-spacing"]?.doubleValue ?? 8) {
                if config["show-icon"]?.boolValue ?? false {
                    PolybarIcon(config: configProvider, glyph: config["glyph"]?.stringValue, systemName: "clock.fill")
                }
                Text(Self.isPreviewRender
                    ? ProcessInfo.processInfo.environment["GLANCE_PREVIEW_TIME_LABEL"] ?? timeProvider.formattedTime(pattern: format, timeZone: timeZone)
                    : timeProvider.formattedTime(pattern: format, timeZone: timeZone))
                    .fontWeight(widgetFont.weight)
                    .font(widgetFont.toFont())
            }
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
        .onAppear { timeProvider.configure(pattern: format, timeZone: timeZone) }
        .onChange(of: format) { _, _ in timeProvider.configure(pattern: format, timeZone: timeZone) }
        .onChange(of: timeZone) { _, _ in timeProvider.configure(pattern: format, timeZone: timeZone) }
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

/// Publishes only changes to the configured label. The shared scheduler uses
/// second boundaries for second-bearing formats and minute boundaries otherwise.
final class TimeProvider: ObservableObject {
    @Published private(set) var formattedTime = ""
    private let formattingCache = DateFormattingCache()
    private var pattern = "E d, H:mm"
    private var timeZone: String?
    private let scheduleID = UUID()
    private var observers: [NSObjectProtocol] = []

    init() {
        update(at: Date())
        schedule()
        observers = [Notification.Name.NSSystemClockDidChange, .NSSystemTimeZoneDidChange, NSLocale.currentLocaleDidChangeNotification].map { name in
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.update(at: Date())
                self?.schedule()
            }
        }
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        let id = scheduleID
        if Thread.isMainThread { WidgetUpdateScheduler.shared.cancel(id) }
        else { DispatchQueue.main.async { WidgetUpdateScheduler.shared.cancel(id) } }
    }

    /// ICU second/fraction/millisecond fields outside quoted literals require
    /// second updates. All other date/time formats can wait for the next minute.
    static func refreshInterval(for pattern: String) -> TimeInterval {
        var quoted = false
        for character in pattern {
            if character == "'" { quoted.toggle() }
            else if !quoted && "sSA".contains(character) { return 1 }
        }
        return 60
    }

    private func schedule() {
        let interval = Self.refreshInterval(for: pattern)
        let now = Date().timeIntervalSince1970
        let delay = interval - now.truncatingRemainder(dividingBy: interval)
        WidgetUpdateScheduler.shared.schedule(scheduleID, every: interval, after: delay) { [weak self] in
            self?.update(at: Date())
            self?.schedule() // Re-align after tolerance, sleep or wall-clock changes.
        }
    }

    func configure(pattern: String, timeZone: String?) {
        guard self.pattern != pattern || self.timeZone != timeZone else { return }
        self.pattern = pattern
        self.timeZone = timeZone
        update(at: Date())
        schedule()
    }

    func update(at date: Date) {
        let text = format(pattern: pattern, date: date, timeZone: timeZone)
        if text != formattedTime { formattedTime = text }
    }

    func formattedTime(pattern: String, timeZone: String?) -> String {
        format(pattern: pattern, date: Date(), timeZone: timeZone)
    }

    func format(pattern: String, date: Date, timeZone: String?) -> String {
        formattingCache.string(pattern: pattern, date: date, timeZone: timeZone)
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
