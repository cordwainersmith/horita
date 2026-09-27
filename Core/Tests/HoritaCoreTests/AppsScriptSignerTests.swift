import Foundation
import Testing
@testable import HoritaCore

@Suite struct AppsScriptSignerTests {
    let secret = "3f9a1c0e5b7d2468ace013579bdf2468"

    @Test func eventsVector() {
        let canonical = AppsScriptSigner.canonicalString(
            action: "events", ts: "1790000000", nonce: "0123456789abcdef0123456789abcdef",
            from: "2026-09-24T00:00:00Z", to: "2026-09-26T00:00:00Z", cal: "primary,team@group.calendar.google.com")
        #expect(canonical == "v1\nevents\n1790000000\n0123456789abcdef0123456789abcdef\n2026-09-24T00:00:00Z\n2026-09-26T00:00:00Z\nprimary,team@group.calendar.google.com")
        #expect(AppsScriptSigner.signature(canonical: canonical, secret: secret) == "1ed076cc4a5f2977944cdaf7110b1d9791bdae87c29c1f47148dae5d5c357ab7")
    }

    @Test func calendarsVector() {
        let canonical = AppsScriptSigner.canonicalString(
            action: "calendars", ts: "1790000000", nonce: "ffffffffffffffffffffffffffffffff", from: "", to: "", cal: "")
        #expect(canonical == "v1\ncalendars\n1790000000\nffffffffffffffffffffffffffffffff\n\n\n")
        #expect(canonical.split(separator: "\n", omittingEmptySubsequences: false).count == 7)
        #expect(!canonical.hasSuffix("\n\n\n\n"))
        #expect(AppsScriptSigner.signature(canonical: canonical, secret: secret) == "52e675babe37c2ce4e924dacaa549b69f0b95a6562c81dfd5b5530c22abaf2f0")
    }

    @Test func signedQueryItemsMatchVector() {
        let items = AppsScriptSigner.signedQueryItems(
            action: "events", from: "2026-09-24T00:00:00Z", to: "2026-09-26T00:00:00Z",
            cal: "primary,team@group.calendar.google.com", secret: secret,
            now: Date(timeIntervalSince1970: 1_790_000_000), nonce: "0123456789abcdef0123456789abcdef")
        #expect(items.map(\.name) == ["action", "ts", "nonce", "from", "to", "cal", "sig"])
        #expect(items.last?.value == "1ed076cc4a5f2977944cdaf7110b1d9791bdae87c29c1f47148dae5d5c357ab7")
        #expect(items[1].value == "1790000000")
        #expect(items[5].value == "primary,team@group.calendar.google.com")
    }

    @Test func randomHexIsWellFormedAndUnique() {
        let hex = try! NSRegularExpression(pattern: "^[0-9a-f]{32}$")
        for value in [AppsScriptSigner.generateSecret(), AppsScriptSigner.generateNonce()] {
            #expect(hex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) != nil, "\(value)")
        }
        #expect(AppsScriptSigner.generateNonce() != AppsScriptSigner.generateNonce())
        #expect(AppsScriptSigner.generateSecret() != AppsScriptSigner.generateSecret())
    }
}
