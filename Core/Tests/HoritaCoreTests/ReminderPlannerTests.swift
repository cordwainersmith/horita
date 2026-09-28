import Foundation
import Testing
@testable import HoritaCore

@Suite struct ReminderPlannerTests {
    func due(_ events: [Event], now: Date, lead: Int = 2, muted: Set<String> = [], handled: Set<String> = []) -> [Event] {
        ReminderPlanner.due(events: events, now: now, leadMinutes: lead, muted: muted, excluding: handled)
    }

    @Test func leadBoundary() {
        let event = makeEvent(start: Fixtures.at(10, 0), end: Fixtures.at(10, 30))
        #expect(due([event], now: Fixtures.at(9, 58)) == [event])
        #expect(due([event], now: Fixtures.at(9, 58).addingTimeInterval(-1)).isEmpty)
        #expect(due([event], now: Fixtures.at(9, 55), lead: 5) == [event])
    }

    @Test func lateGraceAfterWake() {
        let event = makeEvent(start: Fixtures.at(10, 0), end: Fixtures.at(10, 30))
        #expect(due([event], now: Fixtures.at(10, 4)) == [event])
        #expect(due([event], now: Fixtures.at(10, 5)).isEmpty)
        let short = makeEvent(start: Fixtures.at(10, 0), end: Fixtures.at(10, 2))
        #expect(due([short], now: Fixtures.at(10, 3)).isEmpty)
    }

    @Test func skipsMutedHandledAndNonCandidates() {
        let start = Fixtures.at(10, 0), end = Fixtures.at(10, 30), now = Fixtures.at(9, 59)
        let muted = makeEvent(title: "Muted", start: start, end: end, seriesID: "s")
        let handled = makeEvent(id: "done", title: "Handled", start: start, end: end)
        let others = [
            makeEvent(title: "Declined", start: start, end: end, myResponse: .declined),
            makeEvent(title: "Tentative", start: start, end: end, myResponse: .tentative),
            makeEvent(title: "No link", start: start, end: end, location: "Room 4"),
            makeEvent(title: "Solo", start: start, end: end, attendees: [Fixtures.me]),
        ]
        #expect(due([muted, handled] + others, now: now, muted: [muted.muteKey], handled: ["done"]).isEmpty)
    }

    @Test func severalDueAreSortedByStart() {
        let later = makeEvent(title: "B", start: Fixtures.at(10, 1), end: Fixtures.at(10, 30))
        let earlier = makeEvent(title: "A", start: Fixtures.at(10, 0), end: Fixtures.at(10, 30))
        #expect(due([later, earlier], now: Fixtures.at(9, 59)) == [earlier, later])
    }
}
