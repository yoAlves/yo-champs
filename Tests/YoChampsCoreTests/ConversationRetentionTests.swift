import Foundation
import Testing
@testable import YoChampsCore

@Suite("ConversationRetention")
struct ConversationRetentionTests {
    private func makeConversation(
        _ turns: [(user: String, assistant: String)],
        schemaVersion: Int = 1
    ) -> Conversation {
        Conversation(
            schemaVersion: schemaVersion,
            messages: turns.flatMap { turn in
                [
                    LLMMessage(role: .user, content: turn.user),
                    LLMMessage(role: .assistant, content: turn.assistant),
                ]
            }
        )
    }

    private func encodedSize(_ conversation: Conversation) -> Int {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? encoder.encode(conversation))?.count ?? .max
    }

    @Test("defaults to a two mebibyte cap and keeps a conversation that fits")
    func keepsFittingConversation() {
        let original = makeConversation([("hello", "hi"), ("again", "sure")])
        let retention = ConversationRetention()

        #expect(ConversationRetention.defaultMaxBytes == 2 * 1024 * 1024)
        #expect(retention.maxBytes == ConversationRetention.defaultMaxBytes)
        #expect(retention.trim(original) == original)
    }

    @Test("keeps an empty conversation unchanged")
    func keepsEmptyConversation() {
        let original = Conversation()

        #expect(ConversationRetention().trim(original) == original)
    }

    @Test("drops the oldest complete turns first when over the cap")
    func dropsOldestTurns() {
        let filler = String(repeating: "a", count: 900)
        let original = makeConversation([
            (filler, filler),
            (filler, filler),
            (filler, filler),
            ("newest question", "newest answer"),
        ])
        let retention = ConversationRetention(maxBytes: 2500)

        let trimmed = retention.trim(original)

        #expect(trimmed.messages.count < original.messages.count)
        #expect(trimmed.messages == Array(original.messages.suffix(trimmed.messages.count)))
        #expect(trimmed.messages.last == LLMMessage(role: .assistant, content: "newest answer"))
        #expect(encodedSize(trimmed) <= 2500)
    }

    @Test("keeps one oversized newest turn instead of losing the conversation")
    func keepsOversizedNewestTurn() {
        let huge = String(repeating: "b", count: 2000)
        let original = makeConversation([("q", "a"), (huge, huge)])
        let retention = ConversationRetention(maxBytes: 500)

        let trimmed = retention.trim(original)

        #expect(trimmed == makeConversation([(huge, huge)]))
    }

    @Test("preserves the schema version")
    func preservesSchemaVersion() {
        let filler = String(repeating: "c", count: 900)
        let original = makeConversation(
            [(filler, filler), (filler, filler)],
            schemaVersion: 3
        )
        let retention = ConversationRetention(maxBytes: 2000)

        let trimmed = retention.trim(original)

        #expect(trimmed.schemaVersion == 3)
        #expect(trimmed.messages.count == 2)
    }

    @Test("leaves the surviving message content untouched")
    func keepsContentIntact() {
        let filler = String(repeating: "d", count: 1000)
        let content = "first line\n  second line\n\t\"quoted\" — ok"
        let original = makeConversation([(filler, filler), (content, content)])
        let retention = ConversationRetention(maxBytes: 600)

        let trimmed = retention.trim(original)

        #expect(trimmed.messages == [
            LLMMessage(role: .user, content: content),
            LLMMessage(role: .assistant, content: content),
        ])
    }
}
