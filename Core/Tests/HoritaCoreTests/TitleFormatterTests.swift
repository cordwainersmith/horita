import Foundation
import Testing
@testable import HoritaCore

@Suite struct TitleFormatterTests {
    let now = Date(timeIntervalSince1970: 1_790_000_000)

    @Test(arguments: [(59, "now"), (60, "in 1m"), (61, "in 2m"), (3600, "in 1h"), (3601, "in 1h 1m"), (5400, "in 1h 30m"), (0, "now")])
    func countdown(seconds: Int, expected: String) {
        #expect(TitleFormatter.countdown(until: now.addingTimeInterval(TimeInterval(seconds)), now: now) == expected)
    }

    @Test(arguments: [(1, "1m left"), (60, "1m left"), (61, "2m left"), (3600, "1h left"), (3720, "1h 2m left")])
    func remaining(seconds: Int, expected: String) {
        #expect(TitleFormatter.remaining(until: now.addingTimeInterval(TimeInterval(seconds)), now: now) == expected)
    }

    @Test(arguments: [(1800, "30m"), (3600, "1h"), (5400, "1h 30m"), (0, "0m")])
    func duration(seconds: Int, expected: String) {
        #expect(TitleFormatter.duration(from: now, to: now.addingTimeInterval(TimeInterval(seconds))) == expected)
    }

    @Test func truncatesToMaxLengthIncludingEllipsis() {
        let long = String(repeating: "a", count: 40)
        let result = TitleFormatter.truncate(long, maxLength: 30)
        #expect(result.count == 30)
        #expect(result.hasSuffix("…"))
        #expect(TitleFormatter.truncate(String(repeating: "a", count: 30), maxLength: 30).count == 30)
    }

    @Test func truncatesOnGraphemeBoundaries() {
        let family = "👨‍👩‍👧"
        let result = TitleFormatter.truncate(String(repeating: family, count: 35), maxLength: 10)
        #expect(result.count == 10)
        #expect(result.dropLast().allSatisfy { String($0) == family })
    }

    @Test func normalizesWhitespaceAndEmptyTitles() {
        #expect(TitleFormatter.truncate("  Stand\nup\tnow \r\n", maxLength: 30) == "Stand up now")
        #expect(TitleFormatter.truncate("   ", maxLength: 30) == "Untitled")
        #expect(TitleFormatter.truncate("", maxLength: 30) == "Untitled")
    }

    @Test func statusTextStates() {
        let event = makeEvent(title: "Standup", start: now.addingTimeInterval(1800), end: now.addingTimeInterval(3600))
        #expect(TitleFormatter.statusText(for: .upcoming(event), now: now, hideTitle: false, maxLength: 30) == "Standup \u{00B7} in 30m")
        #expect(TitleFormatter.statusText(for: .upcoming(event), now: now, hideTitle: true, maxLength: 30) == "in 30m")
        let running = makeEvent(title: "Standup", start: now.addingTimeInterval(-600), end: now.addingTimeInterval(1800))
        #expect(TitleFormatter.statusText(for: .ongoing(running), now: now, hideTitle: false, maxLength: 30) == "Standup · 30m left")
        #expect(TitleFormatter.statusText(for: .none, now: now, hideTitle: false, maxLength: 30) == nil)
        #expect(TitleFormatter.statusText(for: .beyondThreshold(event), now: now, hideTitle: false, maxLength: 30) == nil)
        let longTitle = makeEvent(title: "Quarterly business review with partners", start: now.addingTimeInterval(1800), end: now.addingTimeInterval(3600))
        #expect(TitleFormatter.statusText(for: .upcoming(longTitle), now: now, hideTitle: false, maxLength: 10) == "Quarterly… · in 30m")
    }

    @Test func durationFromSeconds() {
        #expect(TitleFormatter.duration(seconds: 3.75 * 3600) == "3h 45m")
        #expect(TitleFormatter.duration(seconds: -5) == "0m")
    }
}
