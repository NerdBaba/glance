import AppKit
import Combine
import EventKit
import Foundation

final class CalendarManager: ObservableObject {
    let configProvider: ConfigProvider
    var config: ConfigData? {
        configProvider.config["calendar"]?.dictionaryValue
    }
    var allowList: [String] {
        config?["allow-list"]?.arrayValue?.compactMap { $0.stringValue }.filter { !$0.isEmpty } ?? []
    }
    var denyList: [String] {
        config?["deny-list"]?.arrayValue?.compactMap { $0.stringValue }.filter { !$0.isEmpty } ?? []
    }

    @Published var nextEvent: EKEvent?
    @Published var todaysEvents: [EKEvent] = []
    @Published var tomorrowsEvents: [EKEvent] = []
    @Published private(set) var hasAccess = true
    private let eventStore = EKEventStore()
    private let logger = AppLogger.shared
    private var timer: Timer?
    private var notificationObservers: [NSObjectProtocol] = []
    private var workspaceWakeObserver: NSObjectProtocol?
    private var refreshWorkItem: DispatchWorkItem?

    init(configProvider: ConfigProvider) {
        self.configProvider = configProvider
        requestAccess()
        setupObservers()
        startMonitoring()
    }

    deinit {
        stopMonitoring()
        notificationObservers.forEach(NotificationCenter.default.removeObserver)
        notificationObservers.removeAll()
        if let workspaceWakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceWakeObserver)
        }
        refreshWorkItem?.cancel()
    }

    private func startMonitoring() {
        // Calendar events don't change every 5 seconds — 60s is plenty
        timer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) {
            [weak self] _ in
            self?.queueRefresh()
        }
        timer?.tolerance = 10
        refreshEvents()
    }

    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func requestAccess() {
        eventStore.requestFullAccessToEvents { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.hasAccess = granted && error == nil
            }
            if granted && error == nil {
                self?.queueRefresh()
            } else {
                self?.logger.warning(
                    "Calendar access not granted: \(error?.localizedDescription ?? "unknown error")",
                    category: .calendar
                )
                DispatchQueue.main.async {
                    self?.nextEvent = nil
                    self?.todaysEvents = []
                    self?.tomorrowsEvents = []
                }
            }
        }
    }

    private func setupObservers() {
        let center = NotificationCenter.default
        notificationObservers.append(
            center.addObserver(
                forName: .EKEventStoreChanged,
                object: eventStore,
                queue: .main
            ) { [weak self] _ in
                self?.queueRefresh()
            }
        )
        notificationObservers.append(
            center.addObserver(
                forName: .NSCalendarDayChanged,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.queueRefresh()
            }
        )
        workspaceWakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.queueRefresh()
        }
    }

    private func queueRefresh(delay: TimeInterval = 0.1) {
        refreshWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.refreshEvents()
        }
        refreshWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func refreshEvents() {
        guard hasAccess else { return }

        let calendars = eventStore.calendars(for: .event)
        let now = Date()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: now)

        guard
            let endOfDay = calendar.date(
                bySettingHour: 23, minute: 59, second: 59, of: now
            ),
            let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfDay),
            let endOfTomorrow = calendar.date(
                bySettingHour: 23, minute: 59, second: 59, of: startOfTomorrow
            )
        else {
            logger.warning("Failed to resolve date ranges for calendar refresh", category: .calendar)
            return
        }

        let todayPredicate = eventStore.predicateForEvents(
            withStart: startOfDay,
            end: endOfDay,
            calendars: calendars
        )
        let todayEvents = filterEvents(
            eventStore.events(matching: todayPredicate)
                .filter { $0.endDate >= now }
                .sorted { $0.startDate < $1.startDate }
        )

        let tomorrowPredicate = eventStore.predicateForEvents(
            withStart: startOfTomorrow,
            end: endOfTomorrow,
            calendars: calendars
        )
        let tomorrowEvents = filterEvents(
            eventStore.events(matching: tomorrowPredicate)
                .sorted { $0.startDate < $1.startDate }
        )

        let regularTodayEvents = todayEvents.filter { !$0.isAllDay }
        let next = regularTodayEvents.first ?? todayEvents.first

        DispatchQueue.main.async {
            self.nextEvent = next
            self.todaysEvents = todayEvents
            self.tomorrowsEvents = tomorrowEvents
        }
    }

    private func filterEvents(_ events: [EKEvent]) -> [EKEvent] {
        var filtered = events
        if !allowList.isEmpty {
            filtered = filtered.filter { allowList.contains($0.calendar.title) }
        }
        if !denyList.isEmpty {
            filtered = filtered.filter { !denyList.contains($0.calendar.title) }
        }
        return filtered
    }

}
