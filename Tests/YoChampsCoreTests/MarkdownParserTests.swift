import Foundation
import Testing
@testable import YoChampsCore

@Suite("MarkdownParser")
struct MarkdownParserTests {
    @Test("bold marker yields one bold run")
    func bold() {
        let parsed = MarkdownParser.parse("**bold**")
        #expect(parsed.runs == [MarkdownText.Run(text: "bold", styles: [.bold])])
        #expect(parsed.string == "bold")
    }

    @Test("bold inside surrounding text keeps the plain runs")
    func boldWithinText() {
        let parsed = MarkdownParser.parse("a **b** c")
        #expect(parsed.runs == [
            MarkdownText.Run(text: "a ", styles: []),
            MarkdownText.Run(text: "b", styles: [.bold]),
            MarkdownText.Run(text: " c", styles: []),
        ])
        #expect(parsed.string == "a b c")
    }

    @Test("strikethrough marker yields one strikethrough run")
    func strikethrough() {
        let parsed = MarkdownParser.parse("~~strike~~")
        #expect(parsed.runs == [MarkdownText.Run(text: "strike", styles: [.strikethrough])])
        #expect(parsed.string == "strike")
    }

    @Test("underscore marker yields one italic run")
    func italic() {
        let parsed = MarkdownParser.parse("_italic_")
        #expect(parsed.runs == [MarkdownText.Run(text: "italic", styles: [.italic])])
        #expect(parsed.string == "italic")
    }

    @Test("underscore inside a word stays literal")
    func snakeCaseStaysPlain() {
        let parsed = MarkdownParser.parse("snake_case_name")
        #expect(parsed.runs == [MarkdownText.Run(text: "snake_case_name", styles: [])])
        #expect(parsed.string == "snake_case_name")
    }

    @Test("single asterisk is never bold")
    func singleAsteriskIsLiteral() {
        let parsed = MarkdownParser.parse("*star*")
        #expect(parsed.runs == [MarkdownText.Run(text: "*star*", styles: [])])
        #expect(parsed.string == "*star*")
    }

    @Test("unclosed marker renders literally")
    func unclosedMarkerStaysLiteral() {
        let parsed = MarkdownParser.parse("**bold")
        #expect(parsed.runs == [MarkdownText.Run(text: "**bold", styles: [])])
        #expect(parsed.string == "**bold")
    }

    @Test("markers next to whitespace are not styling")
    func whitespaceBoundariesAreLiteral() {
        let opening = MarkdownParser.parse("** bold**")
        #expect(opening.runs == [MarkdownText.Run(text: "** bold**", styles: [])])
        #expect(opening.string == "** bold**")

        let closing = MarkdownParser.parse("**bold **")
        #expect(closing.runs == [MarkdownText.Run(text: "**bold **", styles: [])])
        #expect(closing.string == "**bold **")
    }

    @Test("two styles in one line stay separate runs")
    func adjacentStyles() {
        let parsed = MarkdownParser.parse("**bold** ~~strike~~")
        #expect(parsed.runs == [
            MarkdownText.Run(text: "bold", styles: [.bold]),
            MarkdownText.Run(text: " ", styles: []),
            MarkdownText.Run(text: "strike", styles: [.strikethrough]),
        ])
        #expect(parsed.string == "bold strike")
    }

    @Test("nested styles combine on the inner run")
    func nestedStyles() {
        let parsed = MarkdownParser.parse("**bold _italic_**")
        #expect(parsed.runs == [
            MarkdownText.Run(text: "bold ", styles: [.bold]),
            MarkdownText.Run(text: "italic", styles: [.bold, .italic]),
        ])
        #expect(parsed.string == "bold italic")
    }

    @Test("mixed markers reconstruct the visible text")
    func mixedMarkersReconstruct() {
        let parsed = MarkdownParser.parse("**a** ~~b~~ _c_")
        #expect(parsed.string == "a b c")
        #expect(parsed.runs.map(\.styles) == [[.bold], [], [.strikethrough], [], [.italic]])
    }

    @Test("newlines are preserved")
    func newlinesArePreserved() {
        let parsed = MarkdownParser.parse("a\n**b**")
        #expect(parsed.runs == [
            MarkdownText.Run(text: "a\n", styles: []),
            MarkdownText.Run(text: "b", styles: [.bold]),
        ])
        #expect(parsed.string == "a\nb")
    }

    @Test("empty input yields no runs")
    func emptyInput() {
        let parsed = MarkdownParser.parse("")
        #expect(parsed.runs.isEmpty)
        #expect(parsed.string.isEmpty)
    }
}
