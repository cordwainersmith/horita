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

    @Test func marksOverlapAndBackToBack() {
        let a = makeEvent(title: "A", start: Fixtures.at(9, 0), end: Fixtures.at(10, 0))
        let b = makeEvent(title: "B", start: Fixtures.at(9, 30), end: Fixtures.at(10, 30))
        let c = makeEvent(title: "C", start: Fixtures.at(10, 30), end: Fixtures.at(11, 0))
        let d = makeEvent(title: "D", start: Fixtures.at(13, 0), end: Fixtures.at(14, 0))
        let declined = makeEvent(title: "X", start: Fixtures.at(13, 30), end: Fixtures.at(14, 0), myResponse: .declined)
        let rows = layout([a, b, c, d, declined]).rows
        let flags = Dictionary(uniqueKeysWithValues: rows.map { ($0.event.title, [$0.overlapsAnother, $0.backToBack]) })
        #expect(flags["A"] == [true, false])
        #expect(flags["B"] == [true, false])
        #expect(flags["C"] == [false, true])
        #expect(flags["D"] == [false, false])
        #expect(flags["X"] == [false, false])
    }

    @Test func summaryCountsMeetingsWithoutDoubleCountingOverlaps() {
        let a = makeEvent(title: "A", start: Fixtures.at(9, 0), end: Fixtures.at(10, 0))
        let b = makeEvent(title: "B", start: Fixtures.at(9, 30), end: Fixtures.at(10, 30))
        let c = makeEvent(title: "C", start: Fixtures.at(15, 0), end: Fixtures.at(16, 30))
        let solo = makeEvent(title: "Focus", start: Fixtures.at(13, 0), end: Fixtures.at(14, 0), attendees: [Fixtures.me])
        let declined = makeEvent(title: "No", start: Fixtures.at(17, 0), end: Fixtures.at(18, 0), myResponse: .declined)
        let summary = layout([a, b, c, solo, declined]).summary
        #expect(summary == DaySummary(meetingCount: 3, busy: 3 * 3600, freeAfter: Fixtures.at(16, 30)))
    }

    @Test func summaryClipsToTodayAndDropsFreeAfterWhenDone() {
        let overnight = makeEvent(title: "Overnight", start: Fixtures.at(23, 0, dayOffset: -1), end: Fixtures.at(1, 0))
        let morning = makeEvent(title: "Morning", start: Fixtures.at(9, 0), end: Fixtures.at(9, 30))
        let summary = layout([overnight, morning]).summary
        #expect(summary == DaySummary(meetingCount: 2, busy: 1.5 * 3600, freeAfter: nil))
    }

    @Test func noSummaryWithoutMeetings() {
        let solo = makeEvent(title: "Focus", start: Fixtures.at(13, 0), end: Fixtures.at(14, 0), attendees: [Fixtures.me])
        #expect(layout([solo]).summary == nil)
        #expect(layout([]).summary == nil)
    }

    @Test func tomorrowFirstWaitsForTodayToFinish() {
        let today = makeEvent(title: "Today", start: Fixtures.at(15, 0), end: Fixtures.at(16, 0))
        let tomorrow = makeEvent(title: "Tomorrow", start: Fixtures.at(9, 30, dayOffset: 1), end: Fixtures.at(10, 0, dayOffset: 1))
        let calendar = Fixtures.calendar
        #expect(DayLayout.tomorrowFirst(events: [today, tomorrow], now: now, calendar: calendar) == nil)
        #expect(DayLayout.tomorrowFirst(events: [today, tomorrow], now: Fixtures.at(16, 0), calendar: calendar) == tomorrow)
        #expect(DayLayout.tomorrowFirst(events: [tomorrow], now: now, calendar: calendar) == tomorrow)
    }

    @Test func tomorrowFirstSkipsDeclinedAllDayAndCanceled() {
        let declinedToday = makeEvent(title: "No", start: Fixtures.at(15, 0), end: Fixtures.at(16, 0), myResponse: .declined)
        let allDay = makeEvent(title: "OOO", start: Fixtures.at(0, 0, dayOffset: 1), end: Fixtures.at(0, 0, dayOffset: 2), isAllDay: true)
        let declined = makeEvent(title: "Declined", start: Fixtures.at(8, 0, dayOffset: 1), end: Fixtures.at(9, 0, dayOffset: 1), myResponse: .declined)
        let canceled = makeEvent(title: "Canceled", start: Fixtures.at(8, 30, dayOffset: 1), end: Fixtures.at(9, 0, dayOffset: 1), status: .canceled)
        let first = makeEvent(title: "First", start: Fixtures.at(10, 0, dayOffset: 1), end: Fixtures.at(10, 30, dayOffset: 1))
        let events = [declinedToday, allDay, declined, canceled, first]
        #expect(DayLayout.tomorrowFirst(events: events, now: now, calendar: Fixtures.calendar) == first)
    }

    @Test func tomorrowFirstNilWhenTomorrowIsEmpty() {
        let dayAfter = makeEvent(title: "Later", start: Fixtures.at(9, 0, dayOffset: 2), end: Fixtures.at(10, 0, dayOffset: 2))
        #expect(DayLayout.tomorrowFirst(events: [dayAfter], now: now, calendar: Fixtures.calendar) == nil)
    }
}
