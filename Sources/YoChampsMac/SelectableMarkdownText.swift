import AppKit
import SwiftUI
import YoChampsCore

/// Read-only, selectable Markdown text for the chat transcript.
///
/// `NSTextView` is used instead of SwiftUI `Text` because the transcript needs
/// exact selection and copy-on-select; the SwiftUI view reports its laid-out
/// height so the surrounding `ScrollView` scrolls instead of the text clipping
/// or nesting its own scroll view.
struct SelectableMarkdownText: NSViewRepresentable {
    let text: MarkdownText
    let fontSize: CGFloat
    let weight: NSFont.Weight
    let accessibilityIdentifier: String

    init(
        text: MarkdownText,
        fontSize: CGFloat = 13,
        weight: NSFont.Weight = .regular,
        accessibilityIdentifier: String
    ) {
        self.text = text
        self.fontSize = fontSize
        self.weight = weight
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    func makeNSView(context: Context) -> SelectableTextView {
        let textView = SelectableTextView(frame: .zero)
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.isRichText = true
        textView.usesFontPanel = false
        textView.allowsUndo = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        textView.textContainer?.containerSize = NSSize(
            width: 0,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setAccessibilityIdentifier(accessibilityIdentifier)
        return textView
    }

    func updateNSView(_ textView: SelectableTextView, context: Context) {
        textView.setAccessibilityIdentifier(accessibilityIdentifier)

        let attributed = MarkdownAttributedString.make(
            text,
            fontSize: fontSize,
            weight: weight
        )
        // Skipping an identical update keeps the user's selection alive while
        // the transcript re-renders around it (for example, on mascot or
        // panel-state changes).
        if textView.attributedString().isEqual(to: attributed) {
            return
        }
        textView.textStorage?.setAttributedString(attributed)
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView textView: SelectableTextView,
        context: Context
    ) -> CGSize? {
        let width = proposal.width ?? textView.bounds.width
        guard width.isFinite, width > 0,
              let textContainer = textView.textContainer,
              let layoutManager = textView.layoutManager
        else {
            return nil
        }

        textContainer.containerSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        layoutManager.ensureLayout(for: textContainer)
        let usedHeight = layoutManager.usedRect(for: textContainer).height
        return CGSize(
            width: width,
            height: ceil(usedHeight) + textView.textContainerInset.height * 2
        )
    }
}

/// `NSTextView` that copies a non-empty selection when the mouse is released.
final class SelectableTextView: NSTextView {
    var pasteboard: PasteboardWriting = GeneralPasteboard()

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        SelectionCopy.copyIfNeeded(
            selectedRange: selectedRange(),
            text: string,
            to: pasteboard
        )
    }
}

/// Converts Core's provider-agnostic runs into AppKit attributes.
enum MarkdownAttributedString {
    static func make(
        _ text: MarkdownText,
        fontSize: CGFloat = 13,
        weight: NSFont.Weight = .regular
    ) -> NSAttributedString {
        let baseFont = NSFont.systemFont(ofSize: fontSize, weight: weight)
        let attributed = NSMutableAttributedString()

        for run in text.runs {
            var font = baseFont
            if run.styles.contains(.bold) {
                font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
            }
            if run.styles.contains(.italic) {
                font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
            }

            var attributes: [NSAttributedString.Key: Any] = [.font: font]
            if run.styles.contains(.strikethrough) {
                attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            }
            attributed.append(NSAttributedString(string: run.text, attributes: attributes))
        }

        return attributed
    }
}

protocol PasteboardWriting {
    func write(_ string: String)
}

/// Writes a selection to the system pasteboard.
private struct GeneralPasteboard: PasteboardWriting {
    func write(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }
}

enum SelectionCopy {
    /// Copies `selectedRange` from `text` when it is non-empty.
    ///
    /// - Returns: `true` when the pasteboard was written.
    @discardableResult
    static func copyIfNeeded(
        selectedRange: NSRange,
        text: String,
        to pasteboard: some PasteboardWriting
    ) -> Bool {
        guard selectedRange.length > 0,
              let range = Range(selectedRange, in: text)
        else {
            return false
        }
        pasteboard.write(String(text[range]))
        return true
    }
}
