import Foundation

public enum TitleFormatter {
    /// nil means "icon only".
    public static func statusText(for selection: Selection, now: Date, hideTitle: Bool, maxLength: Int) -> String? {
        let event: Event
        let clock: String
        switch selection {
        case .none, .beyondThreshold:
            return nil
        case .upcoming(let e):
            event = e
            clock = countdown(until: e.start, now: now)
        case .ongoing(let e):
            event = e
            clock = remaining(until: e.end, now: now)
        }
        if hideTitle { return clock }
        return "\(truncate(event.title, maxLength: maxLength)) \u{00B7} \(clock)"
    }

    public static func countdown(until date: Date, now: Date) -> String {
        let seconds = date.timeIntervalSince(now)
        if seconds < 60 { return "now" }
        return "in " + hoursAndMinutes(ceilMinutes(seconds))
    }

    public static func remaining(until date: Date, now: Date) -> String {
        hoursAndMinutes(ceilMinutes(date.timeIntervalSince(now))) + " left"
    }

    /// "30m", "1h", "1h 30m". Whole minutes, rounded up.
    public static func duration(from start: Date, to end: Date) -> String {
        duration(seconds: end.timeIntervalSince(start))
    }

    public static func duration(seconds: TimeInterval) -> String {
        hoursAndMinutes(max(ceilMinutes(seconds), 0))
    }

    public static func truncate(_ title: String, maxLength: Int) -> String {
        let cleaned = title
            .replacingOccurrences(of: "\r\n", with: " ")
            .map { $0 == "\n" || $0 == "\r" || $0 == "\t" ? " " : $0 }
        let trimmed = String(cleaned).trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Untitled" }
        if trimmed.count <= maxLength { return trimmed }
        return String(trimmed.prefix(max(maxLength - 1, 1))) + "\u{2026}"
    }

    private static func ceilMinutes(_ seconds: TimeInterval) -> Int {
        Int((seconds / 60).rounded(.up))
    }

    private static func hoursAndMinutes(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0 ? "\(hours)h" : "\(hours)h \(rest)m"
    }
}
