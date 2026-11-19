import AppKit
import Foundation
import Testing
import YoChampsCore
@testable import YoChampsMac

@MainActor
@Suite("SelectableMarkdownText")
struct SelectableMarkdownTextTests {
    private func makeAttributed(
        _ markdown: String,
        fontSize: CGFloat = 13,
        weight: NSFont.Weight = .regular
    ) -> NSAttributedString {
        MarkdownAttributedString.make(
            MarkdownParser.parse(markdown),
            fontSize: fontSize,
            weight: weight
        )
    }

    private func font(of substring: String, in attributed: NSAttributedString) -> NSFont? {
        let range = (attributed.string as NSString).range(of: substring)
        guard range.location != NSNotFound else { return nil }
        return attributed.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont
    }

    @Test("a bold run carries the bold font trait")
    func boldRunUsesBoldTrait() throws {
        let attributed = makeAttributed("plain **strong** tail")

        let bold = try #require(font(of: "strong", in: attributed))
        #expect(NSFontManager.shared.traits(of: bold).contains(.boldFontMask))
        #expect(bold.pointSize == 13)

        let plain = try #require(font(of: "plain", in: attributed))
        #expect(!NSFontManager.shared.traits(of: plain).contains(.boldFontMask))
    }

    @Test("an italic run carries the italic font trait")
    func italicRunUsesItalicTrait() throws {
        let attributed = makeAttributed("plain _slanted_ tail")

        let italic = try #require(font(of: "slanted", in: attributed))
        #expect(NSFontManager.shared.traits(of: italic).contains(.italicFontMask))

        let plain = try #require(font(of: "tail", in: attributed))
        #expect(!NSFontManager.shared.traits(of: plain).contains(.italicFontMask))
    }

    @Test("a strikethrough run carries a single strikethrough style")
    func strikethroughRunUsesStrikethroughStyle() {
        let attributed = makeAttributed("plain ~~gone~~ tail")

        let struckRange = (attributed.string as NSString).range(of: "gone")
        let style = attributed.attribute(.strikethroughStyle, at: struckRange.location, effectiveRange: nil) as? Int
        #expect(style == NSUnderlineStyle.single.rawValue)

        let plainRange = (attributed.string as NSString).range(of: "plain")
        #expect(attributed.attribute(.strikethroughStyle, at: plainRange.location, effectiveRange: nil) == nil)
    }

    @Test("newlines survive conversion and styling stays on its run")
    func newlinesArePreserved() throws {
        let attributed = makeAttributed("first row\n\nsecond **line**")

        #expect(attributed.string == "first row\n\nsecond line")

        let bold = try #require(font(of: "line", in: attributed))
        #expect(NSFontManager.shared.traits(of: bold).contains(.boldFontMask))
    }

    @Test("the requested font size reaches every run")
    func fontSizeIsApplied() throws {
        let attributed = makeAttributed("plain **strong**", fontSize: 17, weight: .medium)

        let plain = try #require(font(of: "plain", in: attributed))
        let bold = try #require(font(of: "strong", in: attributed))
        #expect(plain.pointSize == 17)
        #expect(bold.pointSize == 17)
    }

    @Test("a selected range copies the exact substring once")
    func selectedRangeCopiesSubstringOnce() {
        let pasteboard = FakePasteboard()

        let copied = SelectionCopy.copyIfNeeded(
            selectedRange: NSRange(location: 6, length: 5),
            text: "hello world",
            to: pasteboard
        )

        #expect(copied)
        #expect(pasteboard.writes == ["world"])
    }

    @Test("an empty selection does not touch the pasteboard")
    func emptySelectionDoesNotCopy() {
        let pasteboard = FakePasteboard()

        let copied = SelectionCopy.copyIfNeeded(
            selectedRange: NSRange(location: 3, length: 0),
            text: "hello",
            to: pasteboard
        )

        #expect(!copied)
        #expect(pasteboard.writes.isEmpty)
    }

    @Test("text uses the adaptive label color in every run")
    func textUsesLabelColor() {
        let attributed = makeAttributed("plain **strong** ~~gone~~")

        var matches = true
        attributed.enumerateAttribute(
            .foregroundColor,
            in: NSRange(location: 0, length: attributed.length)
        ) { value, _, _ in
            matches = matches && (value as? NSColor) == NSColor.labelColor
        }
        #expect(matches)
    }

    @Test("selection ranges are measured in UTF-16 code units")
    func selectionRangeUsesUTF16Offsets() {
        let pasteboard = FakePasteboard()

        let copied = SelectionCopy.copyIfNeeded(
            selectedRange: NSRange(location: 1, length: 2),
            text: "a😀b",
            to: pasteboard
        )

        #expect(copied)
        #expect(pasteboard.writes == ["😀"])
    }
}

private final class FakePasteboard: PasteboardWriting {
    private(set) var writes: [String] = []

    func write(_ string: String) {
        writes.append(string)
    }
}
