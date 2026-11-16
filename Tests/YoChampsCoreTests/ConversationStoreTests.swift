import Testing
@testable import YoChampsCore

@Suite("ConversationStore")
struct ConversationStoreTests {
    @Test("starts with an empty schema-versioned conversation")
    func startsEmpty() async throws {
        let store = InMemoryConversationStore()
        let conversation = try await store.load()
        #expect(conversation.schemaVersion == 1)
        #expect(conversation.messages.isEmpty)
    }

    @Test("saves and loads messages")
    func savesAndLoads() async throws {
        let store = InMemoryConversationStore()
        let conversation = Conversation(messages: [
            .init(role: .user, content: "hello"),
            .init(role: .assistant, content: "hi"),
        ])
        try await store.save(conversation)
        #expect(try await store.load() == conversation)
    }

    @Test("clear returns to an empty conversation")
    func clear() async throws {
        let store = InMemoryConversationStore()
        try await store.save(Conversation(messages: [.init(role: .user, content: "x")]))
        try await store.clear()
        #expect(try await store.load().messages.isEmpty)
    }
}
