import Foundation
import UserNotifications

enum PomodoroState: String {
    case idle
    case work
    case shortBreak
    case longBreak
}

final class PomodoroViewModel: ObservableObject {
    @Published var remainingSeconds: Int = 0
    @Published var totalSeconds: Int = 0
    @Published var isRunning: Bool = false
    @Published var currentState: PomodoroState = .idle
    @Published var completedSessions: Int = 0

    var workDuration: Int = 25 * 60
    var shortBreakDuration: Int = 5 * 60
    var longBreakDuration: Int = 15 * 60
    var sessionsBeforeLongBreak: Int = 4

    private var timer: Timer?
    /// Absolute end time — immune to timer drift and RunLoop delays.
    private var endDate: Date?

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(totalSeconds - remainingSeconds) / Double(totalSeconds)
    }

    var timeString: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var stateLabel: String {
        switch currentState {
        case .idle: return "Ready"
        case .work: return "Focus"
        case .shortBreak: return "Short Break"
        case .longBreak: return "Long Break"
        }
    }

    init() {
        requestNotificationPermission()
    }

    func configure(from config: [String: TOMLValue]) {
        if let v = config["work-duration"]?.intValue { workDuration = v * 60 }
        if let v = config["break-duration"]?.intValue { shortBreakDuration = v * 60 }
        if let v = config["long-break-duration"]?.intValue { longBreakDuration = v * 60 }
        if let v = config["sessions-before-long-break"]?.intValue { sessionsBeforeLongBreak = v }
    }

    func start() {
        if currentState == .idle {
            currentState = .work
            totalSeconds = workDuration
            remainingSeconds = workDuration
        }
        endDate = Date().addingTimeInterval(TimeInterval(remainingSeconds))
        isRunning = true
        startTimer()
    }

    func pause() {
        if let endDate {
            remainingSeconds = max(0, Int(ceil(endDate.timeIntervalSinceNow)))
        }
        endDate = nil
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    func reset() {
        endDate = nil
        isRunning = false
        timer?.invalidate()
        timer = nil
        currentState = .idle
        remainingSeconds = 0
        totalSeconds = 0
        completedSessions = 0
    }

    func skip() {
        endDate = nil
        isRunning = false
        timer?.invalidate()
        timer = nil
        transitionToNext()
    }

    private func startTimer() {
        timer?.invalidate()
        let t = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, let endDate = self.endDate else { return }
            let remaining = Int(ceil(endDate.timeIntervalSinceNow))
            if remaining > 0 {
                self.remainingSeconds = remaining
            } else {
                self.remainingSeconds = 0
                self.periodEnded()
            }
        }
        t.tolerance = 0.1
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func periodEnded() {
        pause()
        sendNotification()
        transitionToNext()
        // Auto-start the next period
        start()
    }

    private func transitionToNext() {
        switch currentState {
        case .idle:
            break
        case .work:
            completedSessions += 1
            if completedSessions >= sessionsBeforeLongBreak {
                currentState = .longBreak
                totalSeconds = longBreakDuration
                remainingSeconds = longBreakDuration
                completedSessions = 0
            } else {
                currentState = .shortBreak
                totalSeconds = shortBreakDuration
                remainingSeconds = shortBreakDuration
            }
        case .shortBreak, .longBreak:
            currentState = .work
            totalSeconds = workDuration
            remainingSeconds = workDuration
        }
    }

    private func sendNotification() {
        let content = UNMutableNotificationContent()
        switch currentState {
        case .work:
            content.title = "Focus session complete"
            content.body = "Time for a break!"
        case .shortBreak:
            content.title = "Break is over"
            content.body = "Ready to focus again?"
        case .longBreak:
            content.title = "Long break is over"
            content.body = "Ready to start a new cycle?"
        case .idle:
            return
        }
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "pomodoro-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound]
        ) { _, _ in }
    }

    deinit {
        timer?.invalidate()
    }
}
