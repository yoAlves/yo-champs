import Foundation

/// Parses the small Markdown subset the chat renders: `**bold**`,
/// `~~strikethrough~~` and `_italic_`. A single `*` is never bold, and an
/// underscore inside a word (`snake_case`) stays literal.
///
/// The scan is a single left-to-right pass with a stack of open markers, so it
/// stays linear for typical answers that are re-parsed on every streaming
/// delta. Unmatched markers are emitted as literal text.
public enum MarkdownParser {
    public static func parse(_ input: String) -> MarkdownText {
        let characters = Array(input)
        guard !characters.isEmpty else { return MarkdownText(runs: []) }

        var segments: [Segment] = []
        var open: [OpenMarker] = []
        var index = 0

        while index < characters.count {
            if let marker = closingMarker(at: index, in: characters, open: open) {
                close(marker, segments: &segments, open: &open)
                index += marker.length
            } else if let marker = openingMarker(at: index, in: characters) {
                let text = String(characters[index ..< index + marker.length])
                segments.append(Segment(text: text, styles: [], isMarker: true))
                open.append(
                    OpenMarker(
                        style: marker.style,
                        segmentIndex: segments.count - 1,
                        endIndex: index + marker.length
                    )
                )
                index += marker.length
            } else {
                append(characters[index], to: &segments)
                index += 1
            }
        }

        return MarkdownText(runs: merged(segments))
    }
}

extension MarkdownParser {
    private struct Segment {
        var text: String
        var styles: Set<MarkdownText.Style>
        var isMarker = false
        /// Set when a closing marker ends the styled span so trailing text does
        /// not inherit the style by being appended to the same segment.
        var isSealed = false
    }

    private struct OpenMarker {
        let style: MarkdownText.Style
        let segmentIndex: Int
        let endIndex: Int
    }

    private struct Marker {
        let style: MarkdownText.Style
        let length: Int
    }

    private static func append(_ character: Character, to segments: inout [Segment]) {
        if let last = segments.indices.last, !segments[last].isMarker, !segments[last].isSealed {
            segments[last].text.append(character)
        } else {
            segments.append(Segment(text: String(character), styles: []))
        }
    }

    private static func merged(_ segments: [Segment]) -> [MarkdownText.Run] {
        var runs: [MarkdownText.Run] = []
        for segment in segments where !segment.text.isEmpty {
            if let last = runs.indices.last, runs[last].styles == segment.styles {
                runs[last] = MarkdownText.Run(
                    text: runs[last].text + segment.text,
                    styles: segment.styles
                )
            } else {
                runs.append(MarkdownText.Run(text: segment.text, styles: segment.styles))
            }
        }
        return runs
    }

    private static func close(_ marker: Marker, segments: inout [Segment], open: inout [OpenMarker]) {
        guard let top = open.popLast() else { return }
        // The opening marker was staged as a segment so an unclosed marker can
        // still render literally; drop it now that the pair matched.
        segments[top.segmentIndex].text = ""
        for index in top.segmentIndex ..< segments.count {
            segments[index].styles.insert(marker.style)
        }
        segments[segments.count - 1].isSealed = true
    }

    /// A marker that closes the innermost open run, if `index` starts one.
    private static func closingMarker(
        at index: Int,
        in characters: [Character],
        open: [OpenMarker]
    ) -> Marker? {
        guard let marker = marker(at: index, in: characters), let top = open.last, top.style == marker.style, index > 0,
              !characters[index - 1].isWhitespace else { return nil }
        // Matched pairs always keep the markers' inner text non-empty.
        guard index > top.endIndex else { return nil }
        return marker
    }

    /// A marker that can open a style run, if `index` starts one and the text
    /// right after it is not whitespace.
    private static func openingMarker(at index: Int, in characters: [Character]) -> Marker? {
        guard let marker = marker(at: index, in: characters) else { return nil }
        let next = index + marker.length
        guard next < characters.count, !characters[next].isWhitespace else { return nil }
        return marker
    }

    private static func marker(at index: Int, in characters: [Character]) -> Marker? {
        switch characters[index] {
        case "*" where characters[safe: index + 1] == "*":
            Marker(style: .bold, length: 2)
        case "~" where characters[safe: index + 1] == "~":
            Marker(style: .strikethrough, length: 2)
        case "_" where !isInsideWord(at: index, in: characters):
            Marker(style: .italic, length: 1)
        default:
            nil
        }
    }

    private static func isInsideWord(at index: Int, in characters: [Character]) -> Bool {
        guard let previous = characters[safe: index - 1], let next = characters[safe: index + 1] else {
            return false
        }
        return isWordCharacter(previous) && isWordCharacter(next)
    }

    private static func isWordCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
