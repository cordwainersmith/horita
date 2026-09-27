import Testing
@testable import HoritaCore

@Suite struct HTMLTextTests {
    @Test func stripsTags() {
        #expect(HTMLText.plainText("<b>Agenda</b> for <a href=\"x\">today</a>") == "Agenda for today")
    }

    @Test func blockTagsBecomeSpaces() {
        #expect(HTMLText.plainText("Line one<br>Line two<p>Para</p>") == "Line one Line two Para")
    }

    @Test func decodesEntities() {
        #expect(HTMLText.plainText("Tom &amp; Jerry &lt;3 &quot;hi&quot; &#39;x&#39; &#x41;&#66;&nbsp;end") == "Tom & Jerry <3 \"hi\" 'x' AB end")
        #expect(HTMLText.plainText("&amp;lt;") == "&lt;")
        #expect(HTMLText.plainText("&unknown; stays") == "&unknown; stays")
    }

    @Test func collapsesWhitespace() {
        #expect(HTMLText.plainText("  a \n\n  b\t\tc  ") == "a b c")
    }

    @Test func plainTextUnchanged() {
        #expect(HTMLText.plainText("Just notes") == "Just notes")
    }

    @Test func wrapsAtColumnsAndLimitsLines() {
        let text = Array(repeating: "word", count: 40).joined(separator: " ")
        let wrapped = HTMLText.wrap(text, columns: 20, maxLines: 3)
        let lines = wrapped.split(separator: "\n")
        #expect(lines.count == 3)
        #expect(lines.allSatisfy { $0.count <= 20 })
        #expect(wrapped.hasSuffix("…"))
        #expect(HTMLText.wrap("short text", columns: 60, maxLines: 6) == "short text")
        #expect(HTMLText.wrap("abcdefghij", columns: 4, maxLines: 6) == "abcd\nefgh\nij")
    }
}
