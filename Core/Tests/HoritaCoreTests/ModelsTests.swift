import Foundation
import Testing
@testable import HoritaCore

@Suite struct ModelsTests {
    @Test func sourceKindsAreStable() {
        #expect(SourceKind.allCases.map(\.rawValue) == ["eventKit", "appsScript"])
    }

    @Test func keysCombineSourceAndID() {
        let info = CalendarInfo(id: "abc", source: .appsScript, title: "T", colorHex: "#000000", accountName: nil, isSuggestedDefault: false)
        #expect(info.key == "appsScript:abc")
        let event = makeEvent(start: Fixtures.at(9, 0), end: Fixtures.at(10, 0), source: .eventKit, calendarID: "cal-9")
        #expect(event.calendarKey == "eventKit:cal-9")
    }

    @Test func initComputesMeetingLink() {
        let event = makeEvent(start: Fixtures.at(9, 0), end: Fixtures.at(10, 0), location: "https://meet.google.com/abc-defg-hij")
        #expect(event.meetingLink?.service == .googleMeet)
        let none = makeEvent(start: Fixtures.at(9, 0), end: Fixtures.at(10, 0), location: "Room 4")
        #expect(none.meetingLink == nil)
    }

    @Test func soloRules() {
        let base = (Fixtures.at(9, 0), Fixtures.at(10, 0))
        #expect(makeEvent(start: base.0, end: base.1, attendees: [Fixtures.me, Fixtures.room]).isSolo)
        #expect(makeEvent(start: base.0, end: base.1, attendees: []).isSolo)
        #expect(!makeEvent(start: base.0, end: base.1, attendees: [Fixtures.me, Fixtures.pat]).isSolo)
        #expect(!makeEvent(start: base.0, end: base.1, attendees: [Fixtures.pat]).isSolo)
    }
}
