import Foundation

public enum HTMLText {
    private static let tagPattern = try! NSRegularExpression(pattern: "<[^>]+>")
    private static let entityPattern = try! NSRegularExpression(pattern: "&(#x[0-9a-fA-F]+|#[0-9]+|[a-zA-Z]+);")
    private static let whitespacePattern = try! NSRegularExpression(pattern: "\\s+")

    private static let namedEntities: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " ",
    ]

    public static func plainText(_ html: String) -> String {
        var text = replacing(tagPattern, in: html, with: " ")
        text = decodeEntities(text)
        text = replacing(whitespacePattern, in: text, with: " ")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func wrap(_ text: String, columns: Int, maxLines: Int) -> String {
        var lines: [String] = []
        var current = ""
        for word in text.split(separator: " ") {
            var rest = word
            while !rest.isEmpty {
                if current.isEmpty {
                    let chunk = rest.prefix(columns)
                    current = String(chunk)
                    rest = rest.dropFirst(chunk.count)
                } else if current.count + 1 + rest.count <= columns {
                    current += " " + rest
                    rest = ""
                } else {
                    lines.append(current)
                    current = ""
                }
            }
        }
        if !current.isEmpty { lines.append(current) }
        guard lines.count > maxLines else { return lines.joined(separator: "\n") }

        var kept = Array(lines.prefix(maxLines))
        var last = kept[maxLines - 1]
        if last.count >= columns { last = String(last.prefix(columns - 1)) }
        kept[maxLines - 1] = last + "…"
        return kept.joined(separator: "\n")
    }

    private static func replacing(_ pattern: NSRegularExpression, in text: String, with replacement: String) -> String {
        pattern.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: replacement)
    }

    private static func decodeEntities(_ text: String) -> String {
        let result = NSMutableString(string: text)
        let matches = entityPattern.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for match in matches.reversed() {
            let body = result.substring(with: match.range(at: 1))
            guard let decoded = decodeEntity(body) else { continue }
            result.replaceCharacters(in: match.range, with: decoded)
        }
        return result as String
    }

    private static func decodeEntity(_ body: String) -> String? {
        if body.hasPrefix("#x") || body.hasPrefix("#X") {
            return UInt32(body.dropFirst(2), radix: 16).flatMap(Unicode.Scalar.init).map { String(Character($0)) }
        }
        if body.hasPrefix("#") {
            return UInt32(body.dropFirst(1)).flatMap(Unicode.Scalar.init).map { String(Character($0)) }
        }
        return namedEntities[body.lowercased()]
    }
}
