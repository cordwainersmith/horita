import Foundation

public enum LinkDetector {
    static let zoomPattern = regex(
        #"https://([a-z0-9-]+\.)*zoom(gov)?\.(us|com)/(j|w|s|my)/[^\s"'<>]+"#)
    static let zoomSchemePattern = regex(
        #"zoommtg://[^\s"'<>]+"#)
    static let meetPattern = regex(
        #"https://meet\.google\.com/(?:_meet/)?(?:lookup/[a-z0-9-]+|(?!(?:lookup|landing|new|tel)(?![a-z0-9-]))[a-z0-9-]+)(?:\?[^\s"'<>]*)?"#)
    static let teamsPattern = regex(
        #"https://teams\.microsoft\.com/l/meetup-join/[^\s"'<>]+|https://teams\.(?:microsoft|live)\.com/meet/[^\s"'<>]+"#)
    static let googleRedirectPattern = regex(
        #"https?://(?:www\.)?google\.[a-z.]+/url\?[^\s"'<>]*"#)
    static let safeLinksPattern = regex(
        #"https?://[a-z0-9.-]*safelinks\.protection\.outlook\.com/[^\s"'<>?]*\?[^\s"'<>]*"#)

    private static let trailingPunctuation: Set<Character> = [".", ",", ";", ":", "!", "?", ")", "]", "}", ">", "\"", "'"]
    private static let maxRedirectPasses = 8

    public static func detect(conferenceURL: URL?, url: URL?, location: String?, notes: String?) -> MeetingLink? {
        var fields: [String?] = [conferenceURL?.absoluteString, url?.absoluteString, location, notes]
        if let notes, notes.contains("<") {
            fields.append(HTMLText.plainText(notes))
        }
        for case let field? in fields where !field.isEmpty {
            if let link = firstLink(in: field) { return link }
        }
        return nil
    }

    static func unwrapRedirects(_ text: String) -> String {
        var current = text
        for _ in 0..<maxRedirectPasses {
            var next = replacingWrapped(googleRedirectPattern, param: "q", in: current)
            next = replacingWrapped(safeLinksPattern, param: "url", in: next)
            if next == current { break }
            current = next
        }
        return current
    }

    private static func firstLink(in text: String) -> MeetingLink? {
        let unwrapped = unwrapRedirects(text.replacingOccurrences(of: "&amp;", with: "&"))
        let patterns: [(MeetingService, NSRegularExpression)] = [
            (.zoom, zoomPattern), (.zoom, zoomSchemePattern), (.googleMeet, meetPattern), (.teams, teamsPattern),
        ]
        var best: MeetingLink?
        var bestLength = 0
        for (service, pattern) in patterns {
            for match in pattern.matches(in: unwrapped, range: NSRange(unwrapped.startIndex..., in: unwrapped)) {
                guard let range = Range(match.range, in: unwrapped) else { continue }
                let candidate = trimTrailingPunctuation(String(unwrapped[range]))
                guard candidate.count > bestLength, let url = URL(string: candidate) else { continue }
                best = MeetingLink(service: service, url: url)
                bestLength = candidate.count
            }
        }
        return best
    }

    private static func replacingWrapped(_ pattern: NSRegularExpression, param: String, in text: String) -> String {
        let matches = pattern.matches(in: text, range: NSRange(text.startIndex..., in: text))
        guard !matches.isEmpty else { return text }
        let result = NSMutableString(string: text)
        for match in matches.reversed() {
            let wrapped = result.substring(with: match.range)
            guard let inner = queryValue(named: param, in: wrapped) else { continue }
            result.replaceCharacters(in: match.range, with: inner)
        }
        return result as String
    }

    private static func queryValue(named name: String, in urlString: String) -> String? {
        guard let questionMark = urlString.firstIndex(of: "?") else { return nil }
        let query = urlString[urlString.index(after: questionMark)...]
        for pair in query.split(separator: "&") {
            guard let equals = pair.firstIndex(of: "=") else { continue }
            if pair[..<equals] == name {
                return String(pair[pair.index(after: equals)...]).removingPercentEncoding
            }
        }
        return nil
    }

    private static func trimTrailingPunctuation(_ text: String) -> String {
        var result = text
        while let last = result.last, trailingPunctuation.contains(last) {
            result.removeLast()
        }
        return result
    }

    private static func regex(_ pattern: String) -> NSRegularExpression {
        try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }
}
