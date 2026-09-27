import Foundation
import Testing
@testable import HoritaCore

@Suite struct JoinPlannerTests {
    func link(_ string: String, _ service: MeetingService) -> MeetingLink {
        MeetingLink(service: service, url: URL(string: string)!)
    }

    @Test func zoomMeetingOpensNativelyWithPasscode() {
        let plan = JoinPlanner.plan(for: link("https://us02web.zoom.us/j/123456789?pwd=abc", .zoom), accountEmail: nil)
        #expect(plan.primary.absoluteString == "zoommtg://us02web.zoom.us/join?action=join&confno=123456789&pwd=abc")
        #expect(plan.fallback?.absoluteString == "https://us02web.zoom.us/j/123456789?pwd=abc")
    }

    @Test func zoomWithoutPasscode() {
        let plan = JoinPlanner.plan(for: link("https://zoom.us/j/123", .zoom), accountEmail: nil)
        #expect(plan.primary.absoluteString == "zoommtg://zoom.us/join?action=join&confno=123")
        let webinar = JoinPlanner.plan(for: link("https://zoom.us/w/456", .zoom), accountEmail: nil)
        #expect(webinar.primary.absoluteString == "zoommtg://zoom.us/join?action=join&confno=456")
    }

    @Test func zoomRedirectedLinkKeepsPasscode() {
        let detected = LinkDetector.detect(conferenceURL: nil, url: nil, location: nil,
                                           notes: "https://www.google.com/url?q=https%3A%2F%2Fzoom.us%2Fj%2F123%3Fpwd%3Dabc&sa=D")!
        let plan = JoinPlanner.plan(for: detected, accountEmail: nil)
        #expect(plan.primary.absoluteString == "zoommtg://zoom.us/join?action=join&confno=123&pwd=abc")
    }

    @Test func zoomHTTPSOnlyCases() {
        let personal = JoinPlanner.plan(for: link("https://zoom.us/my/jane", .zoom), accountEmail: nil)
        #expect(personal == JoinPlan(primary: URL(string: "https://zoom.us/my/jane")!, fallback: nil))
        let gov = JoinPlanner.plan(for: link("https://foo.zoomgov.com/j/123", .zoom), accountEmail: nil)
        #expect(gov == JoinPlan(primary: URL(string: "https://foo.zoomgov.com/j/123")!, fallback: nil))
        let shared = JoinPlanner.plan(for: link("https://zoom.us/s/123?zak=x", .zoom), accountEmail: nil)
        #expect(shared.fallback == nil)
        #expect(shared.primary.scheme == "https")
        let scheme = JoinPlanner.plan(for: link("zoommtg://zoom.us/join?confno=1", .zoom), accountEmail: nil)
        #expect(scheme == JoinPlan(primary: URL(string: "zoommtg://zoom.us/join?confno=1")!, fallback: nil))
    }

    @Test func teamsUsesNativeSchemeWithHTTPSFallback() {
        let https = "https://teams.microsoft.com/l/meetup-join/19%3ameeting_abc%40thread.v2/0?context=%7b%22Tid%22%3a%22x%22%7d"
        let plan = JoinPlanner.plan(for: link(https, .teams), accountEmail: nil)
        #expect(plan.primary.absoluteString == "msteams://teams.microsoft.com/l/meetup-join/19%3ameeting_abc%40thread.v2/0?context=%7b%22Tid%22%3a%22x%22%7d")
        #expect(plan.fallback?.absoluteString == https)
    }

    @Test func meetAddsAuthuser() {
        let plan = JoinPlanner.plan(for: link("https://meet.google.com/abc-defg-hij", .googleMeet), accountEmail: "me@example.com")
        let items = URLComponents(url: plan.primary, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(items == [URLQueryItem(name: "authuser", value: "me@example.com")])
        #expect(plan.fallback == nil)
    }

    @Test func meetReplacesExistingAuthuser() {
        let plan = JoinPlanner.plan(for: link("https://meet.google.com/abc-defg-hij?authuser=0&hs=122", .googleMeet), accountEmail: "me@example.com")
        let items = URLComponents(url: plan.primary, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(items.filter { $0.name == "authuser" }.count == 1)
        #expect(items.first { $0.name == "authuser" }?.value == "me@example.com")
        #expect(items.contains(URLQueryItem(name: "hs", value: "122")))
    }

    @Test func meetWithoutEmailIsUnchanged() {
        let plan = JoinPlanner.plan(for: link("https://meet.google.com/abc-defg-hij", .googleMeet), accountEmail: nil)
        #expect(plan == JoinPlan(primary: URL(string: "https://meet.google.com/abc-defg-hij")!, fallback: nil))
    }
}
