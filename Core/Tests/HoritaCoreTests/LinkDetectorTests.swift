import Foundation
import Testing
@testable import HoritaCore

@Suite struct LinkDetectorTests {
    func detect(location: String? = nil, notes: String? = nil, url: URL? = nil, conferenceURL: URL? = nil) -> MeetingLink? {
        LinkDetector.detect(conferenceURL: conferenceURL, url: url, location: location, notes: notes)
    }

    @Test func zoomWithPasscodeInLocation() {
        let link = detect(location: "Join: https://us02web.zoom.us/j/123456789?pwd=abc")
        #expect(link?.service == .zoom)
        #expect(link?.url.absoluteString == "https://us02web.zoom.us/j/123456789?pwd=abc")
    }

    @Test func zoomInsideGoogleRedirect() {
        let link = detect(notes: "https://www.google.com/url?q=https%3A%2F%2Fzoom.us%2Fj%2F123%3Fpwd%3Dabc&sa=D")
        #expect(link?.service == .zoom)
        #expect(link?.url.absoluteString == "https://zoom.us/j/123?pwd=abc")
    }

    @Test func teamsInsideSafeLinks() {
        let inner = "https://teams.microsoft.com/l/meetup-join/19%3ameeting_abc%40thread.v2/0?context=%7b%22Tid%22%3a%22x%22%7d"
        let encoded = inner.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
        let plain = "https://nam12.safelinks.protection.outlook.com/?url=\(encoded)&data=05%7c01&reserved=0"
        let ap = "https://eur01.safelinks.protection.outlook.com/ap/t-59584e83/?url=\(encoded)&data=05"
        for wrapped in [plain, ap] {
            let link = detect(notes: "Click here: \(wrapped)")
            #expect(link?.service == .teams)
            #expect(link?.url.absoluteString == inner)
        }
    }

    @Test func conferenceURLBeatsNotes() {
        let link = detect(notes: "Backup: https://zoom.us/j/111", conferenceURL: URL(string: "https://meet.google.com/abc-defg-hij"))
        #expect(link?.service == .googleMeet)
    }

    @Test func locationBeatsNotes() {
        let link = detect(location: "https://zoom.us/j/222", notes: "https://zoom.us/j/111")
        #expect(link?.url.absoluteString == "https://zoom.us/j/222")
    }

    @Test func htmlNoteDecodesAmpersandEntity() {
        let link = detect(notes: "<a href=\"https://zoom.us/j/1?pwd=x&amp;uname=y\">Join</a>")
        #expect(link?.url.absoluteString == "https://zoom.us/j/1?pwd=x&uname=y")
    }

    @Test func personalRoom() {
        let link = detect(location: "https://zoom.us/my/jane")
        #expect(link?.service == .zoom)
        #expect(link?.url.absoluteString == "https://zoom.us/my/jane")
    }

    @Test func trailingPunctuationTrimmed() {
        #expect(detect(notes: "(https://meet.google.com/abc-defg-hij).")?.url.absoluteString == "https://meet.google.com/abc-defg-hij")
        #expect(detect(notes: "See https://zoom.us/j/123.")?.url.absoluteString == "https://zoom.us/j/123")
    }

    @Test func redirectUnwrappingIsBounded() {
        let selfReferential = "https://www.google.com/url?q=https%3A%2F%2Fwww.google.com%2Furl%3Fq%3Dhttps%253A%252F%252Fwww.google.com%252Furl%253Fq%253Dloop"
        #expect(!LinkDetector.unwrapRedirects(selfReferential).isEmpty)

        var deep = "https://zoom.us/j/123"
        for _ in 0..<12 {
            deep = "https://www.google.com/url?q=" + deep.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
        }
        #expect(LinkDetector.unwrapRedirects(deep).hasPrefix("https://www.google.com/url?q="))

        var shallow = "https://zoom.us/j/123"
        for _ in 0..<3 {
            shallow = "https://www.google.com/url?q=" + shallow.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
        }
        #expect(LinkDetector.unwrapRedirects(shallow) == "https://zoom.us/j/123")
    }

    @Test func noLinkAnywhere() {
        #expect(detect(location: "Room 4", notes: "Bring coffee https://example.com/agenda", url: URL(string: "https://example.com")) == nil)
        #expect(detect() == nil)
    }

    @Test func longestMatchWinsWithinField() {
        let link = detect(location: "https://zoom.us/j/123 or https://zoom.us/j/123?pwd=abc")
        #expect(link?.url.absoluteString == "https://zoom.us/j/123?pwd=abc")
    }

    @Test func zoomVariants() {
        #expect(detect(location: "zoommtg://zoom.us/join?confno=1")?.service == .zoom)
        #expect(detect(location: "https://foo.zoomgov.com/j/123")?.service == .zoom)
        #expect(detect(location: "https://foo.bar.zoom.us/j/123")?.url.absoluteString == "https://foo.bar.zoom.us/j/123")
        #expect(detect(location: "https://company.zoom.com/w/987?pwd=x")?.service == .zoom)
    }

    @Test func meetVariants() {
        #expect(detect(location: "https://meet.google.com/lookup/abc-team")?.url.absoluteString == "https://meet.google.com/lookup/abc-team")
        #expect(detect(location: "https://meet.google.com/landing") == nil)
        #expect(detect(location: "https://meet.google.com/new") == nil)
        #expect(detect(location: "https://meet.google.com/new-abcd-efg")?.url.absoluteString == "https://meet.google.com/new-abcd-efg")
        #expect(detect(location: "https://meet.google.com/_meet/abc-defg-hij?authuser=1")?.url.absoluteString == "https://meet.google.com/_meet/abc-defg-hij?authuser=1")
    }

    @Test func teamsVariants() {
        #expect(detect(location: "https://teams.live.com/meet/9876543210?p=abc")?.service == .teams)
        #expect(detect(location: "https://teams.microsoft.com/meet/123?p=x")?.service == .teams)
    }
}
