import Foundation

/// Main-run-loop scheduling shared by native collectors. One one-shot timer
/// sleeps until the next requested update; no periodic idle scan is needed.
final class WidgetUpdateScheduler {
    static let shared = WidgetUpdateScheduler()
    private struct Job {
        let interval: TimeInterval
        var deadline: TimeInterval
        let action: () -> Void
    }
    private var jobs: [UUID: Job] = [:]
    private var timer: Timer?

    func schedule(_ id: UUID, every interval: TimeInterval, after initialDelay: TimeInterval? = nil, action: @escaping () -> Void) {
        precondition(Thread.isMainThread)
        precondition(interval.isFinite && interval > 0)
        jobs[id] = Job(interval: interval, deadline: ProcessInfo.processInfo.systemUptime + max(0.001, initialDelay ?? interval), action: action)
        arm()
    }

    func cancel(_ id: UUID) {
        precondition(Thread.isMainThread)
        jobs.removeValue(forKey: id)
        arm()
    }

    private func arm() {
        timer?.invalidate()
        timer = nil
        guard let deadline = jobs.values.map(\.deadline).min() else { return }
        let delay = max(0.001, deadline - ProcessInfo.processInfo.systemUptime)
        let next = Timer(timeInterval: delay, repeats: false) { [weak self] _ in self?.fire() }
        next.tolerance = min(0.25, delay * 0.1)
        timer = next
        RunLoop.main.add(next, forMode: .common)
    }

    private func fire() {
        let now = ProcessInfo.processInfo.systemUptime
        // Batch nearly simultaneous collectors in the same run-loop turn.
        let due = jobs.filter { $0.value.deadline <= now + 0.01 }
        for (id, job) in due { jobs[id]?.deadline = now + job.interval }
        for (id, job) in due where jobs[id] != nil { job.action() }
        arm()
    }
}
