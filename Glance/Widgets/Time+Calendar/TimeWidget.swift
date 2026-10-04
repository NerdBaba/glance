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

/// Publishes only changes to the configured clock label. A one-second timer
/// still supports patterns containing seconds, but minute-only clocks avoid
/// 59 redundant SwiftUI invalidations each minute.
final class TimeProvider: ObservableObject {
    @Published private(set) var formattedTime = ""
    private let formattingCache = DateFormattingCache()
    private var pattern = "E d, J:mm"
    private var timeZone: String?
    private var timer: Timer?

    init() {
        update(at: Date())
        // TimeProvider is owned by the main-thread SwiftUI view. Timer and
        // publication stay on that run loop; no dedicated running thread is needed.
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.update(at: Date())
        }
        timer?.tolerance = 0.1
    }

    deinit { timer?.invalidate() }

    func configure(pattern: String, timeZone: String?) {
        guard self.pattern != pattern || self.timeZone != timeZone else { return }
        self.pattern = pattern
        self.timeZone = timeZone
        update(at: Date())
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
