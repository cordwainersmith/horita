import Foundation

public enum RowStyle: Equatable, Sendable {
    case declined, past, ongoing, tentative, normal
}

public struct DayRow: Equatable, Sendable {
    public let event: Event
    public let style: RowStyle

    public init(event: Event, style: RowStyle) {
        self.event = event
        self.style = style
    }
}

public struct DaySection: Equatable, Sendable {
    public let day: Date
    public let allDayTitles: [String]
    public let rows: [DayRow]
    public let allPast: Bool

    public init(day: Date, allDayTitles: [String], rows: [DayRow], allPast: Bool) {
        self.day = day
        self.allDayTitles = allDayTitles
        self.rows = rows
        self.allPast = allPast
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
        let rows = todays.filter { !$0.isAllDay }.map { DayRow(event: $0, style: style(of: $0, now: now)) }
        let allPast = !rows.isEmpty && rows.allSatisfy { $0.event.end <= now }
        return DaySection(day: startOfToday, allDayTitles: allDayTitles, rows: rows, allPast: allPast)
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
