import Foundation

/// Plain text split into styled runs by ``MarkdownParser``.
///
/// Runs carry no UI types so the Mac layer can map them to its own rendering
/// primitives without Core depending on AppKit or SwiftUI.
public struct MarkdownText: Equatable, Sendable {
    public enum Style: Hashable, Sendable {
        case bold
        case italic
        case strikethrough
    }

    public struct Run: Equatable, Sendable {
        public let text: String
        public let styles: Set<Style>
    }

    public let runs: [Run]

    /// The visible text: every run joined in order, with matched markers removed.
    public var string: String {
        runs.map(\.text).joined()
    }
}
