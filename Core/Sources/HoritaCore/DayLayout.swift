import Foundation

public enum RowStyle: Equatable, Sendable {
    case declined, past, ongoing, tentative, normal
}

public struct DayRow: Equatable, Sendable {
    public let event: Event
    public let style: RowStyle
    public let overlapsAnother: Bool
    /// Starts exactly when another row ends. Never set together with `overlapsAnother`.
    public let backToBack: Bool

    public init(event: Event, style: RowStyle, overlapsAnother: Bool = false, backToBack: Bool = false) {
        self.event = event
        self.style = style
        self.overlapsAnother = overlapsAnother
        self.backToBack = backToBack
    }
}

public struct DaySummary: Equatable, Sendable {
    public let meetingCount: Int
    public let busy: TimeInterval
    public let freeAfter: Date?

    public init(meetingCount: Int, busy: TimeInterval, freeAfter: Date?) {
        self.meetingCount = meetingCount
        self.busy = busy
        self.freeAfter = freeAfter
    }
}

public struct DaySection: Equatable, Sendable {
    public let day: Date
    public let allDayTitles: [String]
    public let rows: [DayRow]
    public let allPast: Bool
    public let summary: DaySummary?

    public init(day: Date, allDayTitles: [String], rows: [DayRow], allPast: Bool, summary: DaySummary? = nil) {
        self.day = day
        self.allDayTitles = allDayTitles
        self.rows = rows
        self.allPast = allPast
        self.summary = summary
    }
}

public enum DayLayout {
    public static func today(events: [Event], now: Date, calendar: Calendar) -> DaySection {
        let startOfToday = calendar.startOfDay(for: now)
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday.addingTimeInterval(86_400)

        let todays = events
            .filter { $0.status != .canceled && $0.start < endOfToday && $0.end > startOfToday }
            .sorted(by: precedes)

        let allDayTitles = todays.filter(\.isAllDay).map { TitleFormatter.truncate($0.title, maxLength: Int.max) }
        let timed = todays.filter { !$0.isAllDay }
        let busy = timed.filter(isBusy)
        let rows = timed.map { event in
            guard isBusy(event) else { return DayRow(event: event, style: style(of: event, now: now)) }
            let others = busy.filter { $0.id != event.id }
            let overlaps = others.contains { $0.start < event.end && event.start < $0.end }
            let backToBack = !overlaps && others.contains { $0.end == event.start }
            return DayRow(event: event, style: style(of: event, now: now), overlapsAnother: overlaps, backToBack: backToBack)
        }
        let allPast = !rows.isEmpty && rows.allSatisfy { $0.event.end <= now }
        let summary = summary(of: busy.filter { !$0.isSolo }, now: now, dayStart: startOfToday, dayEnd: endOfToday)
        return DaySection(day: startOfToday, allDayTitles: allDayTitles, rows: rows, allPast: allPast, summary: summary)
    }

    /// Tomorrow's first timed, non-declined event, once nothing like that is left today.
    public static func tomorrowFirst(events: [Event], now: Date, calendar: Calendar) -> Event? {
        let startOfToday = calendar.startOfDay(for: now)
        guard let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday),
              let endOfTomorrow = calendar.date(byAdding: .day, value: 2, to: startOfToday)
        else { return nil }
        let timed = events.filter { !$0.isAllDay && $0.status != .canceled && $0.myResponse != .declined }
        if timed.contains(where: { $0.start < startOfTomorrow && $0.end > now }) { return nil }
        return timed
            .filter { $0.start >= startOfTomorrow && $0.start < endOfTomorrow }
            .sorted(by: precedes)
            .first
    }

    private static func isBusy(_ event: Event) -> Bool {
        event.myResponse != .declined
    }

    private static func summary(of meetings: [Event], now: Date, dayStart: Date, dayEnd: Date) -> DaySummary? {
        guard !meetings.isEmpty else { return nil }
        var busy: TimeInterval = 0
        var coveredUntil = dayStart
        for meeting in meetings.sorted(by: { $0.start < $1.start }) {
            let start = max(meeting.start, coveredUntil)
            let end = min(meeting.end, dayEnd)
            if end > start { busy += end.timeIntervalSince(start) }
            coveredUntil = max(coveredUntil, end)
        }
        let lastEnd = meetings.map(\.end).max()
        let freeAfter = lastEnd.flatMap { $0 > now && $0 < dayEnd ? $0 : nil }
        return DaySummary(meetingCount: meetings.count, busy: busy, freeAfter: freeAfter)
    }

    private static func style(of event: Event, now: Date) -> RowStyle {
        if event.myResponse == .declined { return .declined }
        if event.end <= now { return .past }
        if event.start <= now && now < event.end { return .ongoing }
        if event.myResponse == .tentative || event.myResponse == .needsAction { return .tentative }
        return .normal
    }

    private static func precedes(_ a: Event, _ b: Event) -> Bool {
        if a.start != b.start { return a.start < b.start }
        if a.end != b.end { return a.end < b.end }
        return a.title < b.title
    }
}
