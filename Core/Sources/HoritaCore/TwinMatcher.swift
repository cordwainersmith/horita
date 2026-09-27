import Foundation

public enum TwinMatcher {
    /// Returns a symmetric map: calendar key -> twin calendar key.
    ///
    /// Two calendars are twins when one is EventKit and the other Apps Script, and either
    /// their normalized titles match and the EventKit account is the script account, or the
    /// Apps Script calendar is the primary one (its id is the account email) and the EventKit
    /// calendar is titled with that email, which is how macOS shows a Google primary calendar.
    public static func twins(eventKit: [CalendarInfo], appsScript: [CalendarInfo], scriptAccountEmail: String?) -> [String: String] {
        guard let scriptAccountEmail, !scriptAccountEmail.isEmpty else { return [:] }
        let email = normalize(scriptAccountEmail)
        var map: [String: String] = [:]

        for gas in appsScript where gas.source == .appsScript {
            let gasTitle = normalize(gas.title)
            let isPrimary = normalize(gas.id) == email
            for ek in eventKit where ek.source == .eventKit {
                guard map[ek.key] == nil, map[gas.key] == nil else { continue }
                let ekTitle = normalize(ek.title)
                let sameAccount = normalize(ek.accountName ?? "") == email
                let titleMatch = ekTitle == gasTitle && sameAccount
                let primaryMatch = isPrimary && ekTitle == email
                if titleMatch || primaryMatch {
                    map[ek.key] = gas.key
                    map[gas.key] = ek.key
                }
            }
        }
        return map
    }

    static func normalize(_ text: String) -> String {
        text.lowercased()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}
