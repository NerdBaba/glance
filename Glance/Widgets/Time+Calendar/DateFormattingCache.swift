import Foundation

/// Reuses the clock and calendar formatters without sharing mutable formatter
/// state between threads. The small bound also handles repeated settings edits.
final class DateFormattingCache {
    private struct Key: Hashable {
        let pattern: String
        let timeZone: String
        let locale: String
        let calendar: Calendar.Identifier
    }

    private let lock = NSLock()
    private var formatters: [Key: DateFormatter] = [:]

    func string(pattern: String, date: Date, timeZone: String?) -> String {
        let locale = Locale.current
        let calendar = Calendar.current
        let zone = timeZone.flatMap(TimeZone.init(identifier:)) ?? .current
        let key = Key(pattern: pattern, timeZone: zone.identifier, locale: locale.identifier,
                      calendar: calendar.identifier)
        lock.lock()
        defer { lock.unlock() }
        let formatter: DateFormatter
        if let cached = formatters[key] {
            formatter = cached
        } else {
            if formatters.count >= 16 { formatters.removeAll(keepingCapacity: true) }
            formatter = DateFormatter()
            formatter.locale = locale
            formatter.calendar = calendar
            formatter.timeZone = zone
            formatter.dateFormat = pattern
            formatters[key] = formatter
        }
        return formatter.string(from: date)
    }
}
