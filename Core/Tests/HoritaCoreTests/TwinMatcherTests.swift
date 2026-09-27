import Testing
@testable import HoritaCore

@Suite struct TwinMatcherTests {
    func ek(_ id: String, _ title: String, account: String?) -> CalendarInfo {
        CalendarInfo(id: id, source: .eventKit, title: title, colorHex: "#000000", accountName: account, isSuggestedDefault: true)
    }

    func gas(_ id: String, _ title: String) -> CalendarInfo {
        CalendarInfo(id: id, source: .appsScript, title: title, colorHex: "#000000", accountName: "jane@example.com", isSuggestedDefault: true)
    }

    @Test func matchesByTitleAndAccount() {
        let team = ek("ek-team", "Team  Calendar", account: "Jane@Example.com")
        let other = ek("ek-other", "Team Calendar", account: "work@corp.com")
        let g = gas("team@group.calendar.google.com", "team calendar")
        let twins = TwinMatcher.twins(eventKit: [team, other], appsScript: [g], scriptAccountEmail: "jane@example.com")
        #expect(twins == ["eventKit:ek-team": "appsScript:team@group.calendar.google.com",
                          "appsScript:team@group.calendar.google.com": "eventKit:ek-team"])
    }

    @Test func matchesPrimaryByEmailTitleDespiteDifferentSummary() {
        let primary = ek("ek-primary", "jane@example.com", account: "Google")
        let g = gas("jane@example.com", "Jane Doe")
        let twins = TwinMatcher.twins(eventKit: [primary], appsScript: [g], scriptAccountEmail: "Jane@example.com")
        #expect(twins["eventKit:ek-primary"] == "appsScript:jane@example.com")
        #expect(twins["appsScript:jane@example.com"] == "eventKit:ek-primary")
    }

    @Test func noMatchWhenAccountDiffers() {
        let cal = ek("ek-1", "Jane Doe", account: "work@corp.com")
        let g = gas("jane@example.com", "Jane Doe")
        #expect(TwinMatcher.twins(eventKit: [cal], appsScript: [g], scriptAccountEmail: "jane@example.com").isEmpty)
    }

    @Test func noEmailMeansNoTwins() {
        let cal = ek("ek-1", "Team", account: "jane@example.com")
        let g = gas("team@group.calendar.google.com", "Team")
        #expect(TwinMatcher.twins(eventKit: [cal], appsScript: [g], scriptAccountEmail: nil).isEmpty)
        #expect(TwinMatcher.twins(eventKit: [cal], appsScript: [g], scriptAccountEmail: "").isEmpty)
    }

    @Test func eachCalendarPairsAtMostOnce() {
        let a = ek("ek-a", "Team", account: "jane@example.com")
        let b = ek("ek-b", "Team", account: "jane@example.com")
        let g = gas("team@group.calendar.google.com", "Team")
        let twins = TwinMatcher.twins(eventKit: [a, b], appsScript: [g], scriptAccountEmail: "jane@example.com")
        #expect(twins.count == 2)
        #expect(twins["eventKit:ek-a"] == g.key)
        #expect(twins["eventKit:ek-b"] == nil)
    }
}
