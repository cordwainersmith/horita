import Foundation
import Testing
@testable import HoritaCore

@Suite struct NextEventSelectorTests {
    let now = Fixtures.at(9, 0)

    func select(_ events: [Event], now: Date? = nil, threshold: Int = 60) -> Selection {
        NextEventSelector.select(from: events, now: now ?? self.now, thresholdMinutes: threshold)
    }

    @Test func noEvents() {
        #expect(select([]) == .none)
    }

    @Test func nonCandidatesYieldNone() {
        let start = Fixtures.at(9, 30), end = Fixtures.at(10, 0)
        let events = [
            makeEvent(title: "all day", start: Fixtures.at(0, 0), end: Fixtures.at(0, 0, dayOffset: 1), isAllDay: true),
            makeEvent(title: "declined", start: start, end: end, myResponse: .declined),
            makeEvent(title: "tentative", start: start, end: end, myResponse: .tentative),
            makeEvent(title: "needsAction", start: start, end: end, myResponse: .needsAction),
            makeEvent(title: "canceled", start: start, end: end, status: .canceled),
            makeEvent(title: "solo", start: start, end: end, attendees: [Fixtures.me]),
            makeEvent(title: "no link", start: start, end: end, location: "Room 4"),
        ]
        for event in events {
            #expect(!NextEventSelector.isTitleCandidate(event), "\(event.title)")
        }
        #expect(select(events) == .none)
    }

    @Test func within30MinutesIsUpcoming() {
        let event = makeEvent(start: Fixtures.at(9, 30), end: Fixtures.at(10, 0))
        #expect(select([event]) == .upcoming(event))
    }

    @Test func thresholdBoundary() {
        let at61 = makeEvent(start: Fixtures.at(10, 1), end: Fixtures.at(10, 30))
        #expect(select([at61]) == .beyondThreshold(at61))
        let at60 = makeEvent(start: Fixtures.at(10, 0), end: Fixtures.at(10, 30))
        #expect(select([at60]) == .upcoming(at60))
    }

    @Test func ongoingWithNothingWithinLead() {
        let current = makeEvent(title: "Current", start: Fixtures.at(8, 30), end: Fixtures.at(9, 30))
        let later = makeEvent(title: "Later", start: Fixtures.at(9, 20), end: Fixtures.at(10, 0))
        #expect(select([later, current]) == .ongoing(current))
    }

    @Test func ongoingHandsOffTenMinutesBeforeNext() {
        let current = makeEvent(title: "Current", start: Fixtures.at(8, 30), end: Fixtures.at(9, 30))
        let in10 = makeEvent(title: "Next", start: Fixtures.at(9, 10), end: Fixtures.at(9, 40))
        #expect(select([current, in10]) == .upcoming(in10))
        let in11 = makeEvent(title: "Next", start: Fixtures.at(9, 11), end: Fixtures.at(9, 40))
        #expect(select([current, in11]) == .ongoing(current))
    }

    @Test func acceptedBeatsNoneAtSameStart() {
        let accepted = makeEvent(title: "B accepted", start: Fixtures.at(9, 30), end: Fixtures.at(10, 0), myResponse: .accepted)
        let unanswered = makeEvent(title: "A none", start: Fixtures.at(9, 30), end: Fixtures.at(10, 0), myResponse: .none, attendees: [Fixtures.pat])
        #expect(NextEventSelector.isTitleCandidate(unanswered))
        #expect(select([unanswered, accepted]) == .upcoming(accepted))
    }

    @Test func justEndedIsExcluded() {
        let ended = makeEvent(start: Fixtures.at(8, 0), end: now.addingTimeInterval(-1))
        #expect(select([ended]) == .none)
        let endsNow = makeEvent(start: Fixtures.at(8, 0), end: now)
        #expect(select([endsNow]) == .none)
    }

    @Test func backToBackSwitchesDuringLead() {
        let a = makeEvent(title: "A", start: Fixtures.at(9, 0), end: Fixtures.at(10, 0))
        let b = makeEvent(title: "B", start: Fixtures.at(10, 0), end: Fixtures.at(10, 30))
        #expect(select([a, b], now: Fixtures.at(9, 52)) == .upcoming(b))
        #expect(select([a, b], now: Fixtures.at(9, 49)) == .ongoing(a))
    }

    @Test func selfPlusRoomIsSolo() {
        let event = makeEvent(start: Fixtures.at(9, 30), end: Fixtures.at(10, 0), attendees: [Fixtures.me, Fixtures.room])
        #expect(select([event]) == .none)
    }

    @Test func zeroAttendeesIsSolo() {
        let event = makeEvent(start: Fixtures.at(9, 30), end: Fixtures.at(10, 0), attendees: [])
        #expect(select([event]) == .none)
    }

    @Test func nextDayEarlyMeetingLateAtNight() {
        let event = makeEvent(start: Fixtures.at(0, 15, dayOffset: 1), end: Fixtures.at(0, 45, dayOffset: 1))
        #expect(select([event], now: Fixtures.at(23, 30)) == .upcoming(event))
    }

    @Test func tieBreakByEndThenTitle() {
        let start = Fixtures.at(9, 30)
        let longer = makeEvent(title: "A", start: start, end: Fixtures.at(11, 0))
        let shorter = makeEvent(title: "Z", start: start, end: Fixtures.at(10, 0))
        #expect(select([longer, shorter]) == .upcoming(shorter))
        let a = makeEvent(title: "A", start: start, end: Fixtures.at(10, 0))
        let b = makeEvent(title: "B", start: start, end: Fixtures.at(10, 0))
        #expect(select([b, a]) == .upcoming(a))
    }
}
