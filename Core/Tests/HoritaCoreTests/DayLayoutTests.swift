import Foundation
import Testing
@testable import HoritaCore

@Suite struct DayLayoutTests {
    let now = Fixtures.at(12, 0)

    func layout(_ events: [Event], now: Date? = nil) -> DaySection {
        DayLayout.today(events: events, now: now ?? self.now, calendar: Fixtures.calendar)
    }

    @Test func includesEventsOverlappingToday() {
        let overnight = makeEvent(title: "Overnight", start: Fixtures.at(23, 0, dayOffset: -1), end: Fixtures.at(1, 0))
        let late = makeEvent(title: "Late", start: Fixtures.at(23, 30), end: Fixtures.at(0, 30, dayOffset: 1))
        let tomorrow = makeEvent(title: "Tomorrow", start: Fixtures.at(9, 0, dayOffset: 1), end: Fixtures.at(10, 0, dayOffset: 1))
        let yesterday = makeEvent(title: "Yesterday", start: Fixtures.at(9, 0, dayOffset: -1), end: Fixtures.at(10, 0, dayOffset: -1))
        let endsAtMidnight = makeEvent(title: "EndsMidnight", start: Fixtures.at(23, 0, dayOffset: -1), end: Fixtures.at(0, 0))
        let section = layout([tomorrow, late, yesterday, overnight, endsAtMidnight])
        #expect(section.rows.map(\.event.title) == ["Overnight", "Late"])
        #expect(section.day == Fixtures.at(0, 0))
    }

    @Test func collapsesAllDayEvents() {
        let ooo = makeEvent(title: "OOO", start: Fixtures.at(0, 0), end: Fixtures.at(0, 0, dayOffset: 1), isAllDay: true)
        let holiday = makeEvent(title: "Holiday", start: Fixtures.at(0, 0, dayOffset: -1), end: Fixtures.at(0, 0, dayOffset: 2), isAllDay: true)
        let untitled = makeEvent(title: "", start: Fixtures.at(0, 0), end: Fixtures.at(0, 0, dayOffset: 1), isAllDay: true)
        let timed = makeEvent(title: "Standup", start: Fixtures.at(10, 0), end: Fixtures.at(10, 30))
        let section = layout([ooo, timed, holiday, untitled])
        #expect(section.allDayTitles == ["Holiday", "Untitled", "OOO"])
        #expect(section.rows.map(\.event.title) == ["Standup"])
    }

    @Test func stylePriority() {
        let declinedPast = makeEvent(title: "DP", start: Fixtures.at(9, 0), end: Fixtures.at(10, 0), myResponse: .declined)
        let declinedFuture = makeEvent(title: "DF", start: Fixtures.at(14, 0), end: Fixtures.at(15, 0), myResponse: .declined)
        let pastTentative = makeEvent(title: "PT", start: Fixtures.at(9, 0), end: Fixtures.at(10, 0), myResponse: .tentative)
        let ongoingTentative = makeEvent(title: "OT", start: Fixtures.at(11, 30), end: Fixtures.at(12, 30), myResponse: .tentative)
        let ongoing = makeEvent(title: "O", start: Fixtures.at(12, 0), end: Fixtures.at(12, 30))
        let needsAction = makeEvent(title: "NA", start: Fixtures.at(14, 0), end: Fixtures.at(15, 0), myResponse: .needsAction)
        let tentative = makeEvent(title: "T", start: Fixtures.at(14, 0), end: Fixtures.at(15, 0), myResponse: .tentative)
        let normal = makeEvent(title: "N", start: Fixtures.at(14, 0), end: Fixtures.at(15, 0))
        let styles = Dictionary(uniqueKeysWithValues: layout([declinedPast, declinedFuture, pastTentative, ongoingTentative, ongoing, needsAction, tentative, normal]).rows.map { ($0.event.title, $0.style) })
        #expect(styles["DP"] == .declined)
        #expect(styles["DF"] == .declined)
        #expect(styles["PT"] == .past)
        #expect(styles["OT"] == .ongoing)
        #expect(styles["O"] == .ongoing)
        #expect(styles["NA"] == .tentative)
        #expect(styles["T"] == .tentative)
        #expect(styles["N"] == .normal)
    }

    @Test func allPastSemantics() {
        let past = makeEvent(title: "Past", start: Fixtures.at(9, 0), end: Fixtures.at(10, 0))
        let declinedPast = makeEvent(title: "DP", start: Fixtures.at(9, 0), end: Fixtures.at(10, 0), myResponse: .declined)
        let future = makeEvent(title: "Future", start: Fixtures.at(14, 0), end: Fixtures.at(15, 0))
        let allDay = makeEvent(title: "OOO", start: Fixtures.at(0, 0), end: Fixtures.at(0, 0, dayOffset: 1), isAllDay: true)
        #expect(layout([past, declinedPast]).allPast)
        #expect(!layout([past, future]).allPast)
        #expect(!layout([]).allPast)
        #expect(!layout([allDay]).allPast)
        let endsNow = makeEvent(title: "EndsNow", start: Fixtures.at(11, 0), end: now)
        #expect(layout([endsNow]).allPast)
    }

    @Test func rowsSortedByStartEndTitle() {
        let b = makeEvent(title: "B", start: Fixtures.at(10, 0), end: Fixtures.at(11, 0))
        let a = makeEvent(title: "A", start: Fixtures.at(10, 0), end: Fixtures.at(11, 0))
        let shorter = makeEvent(title: "S", start: Fixtures.at(10, 0), end: Fixtures.at(10, 30))
        let early = makeEvent(title: "E", start: Fixtures.at(8, 0), end: Fixtures.at(8, 30))
        #expect(layout([b, a, shorter, early]).rows.map(\.event.title) == ["E", "S", "A", "B"])
    }

    @Test func canceledExcludedAndEmptyDay() {
        let canceled = makeEvent(title: "C", start: Fixtures.at(10, 0), end: Fixtures.at(11, 0), status: .canceled)
        let section = layout([canceled])
        #expect(section.rows.isEmpty)
        #expect(section.allDayTitles.isEmpty)
        #expect(!section.allPast)
    }
}
