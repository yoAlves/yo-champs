import Foundation

/// Caps stored history by its on-disk size. History is written in complete
/// user/assistant pairs, so dropping always removes a whole turn and never
/// leaves an assistant answer without its question.
public struct ConversationRetention: Sendable, Equatable {
    public static let defaultMaxBytes = 2 * 1024 * 1024

    public let maxBytes: Int

    public init(maxBytes: Int = ConversationRetention.defaultMaxBytes) {
        precondition(maxBytes > 0, "maxBytes must be positive")
        self.maxBytes = maxBytes
    }

    /// Drops the oldest complete turns until the encoded conversation fits,
    /// keeping the newest turn even when it alone exceeds the cap.
    public func trim(_ conversation: Conversation) -> Conversation {
        guard encodedByteCount(of: conversation) > maxBytes else {
            return conversation
        }

        var trimmed = conversation
        while encodedByteCount(of: trimmed) > maxBytes, trimmed.messages.count > 2 {
            trimmed.messages.removeFirst(2)
        }
        return trimmed
    }

    /// Same encoding shape as FileConversationStore.save, so the cap tracks the
    /// file the history is actually written to.
    private func encodedByteCount(of conversation: Conversation) -> Int {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? encoder.encode(conversation))?.count ?? .max
    }
}
