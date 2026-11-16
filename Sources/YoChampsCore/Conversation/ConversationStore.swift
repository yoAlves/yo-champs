import Foundation

public struct Conversation: Codable, Sendable, Equatable {
    public let schemaVersion: Int
    public var messages: [LLMMessage]

    public init(schemaVersion: Int = 1, messages: [LLMMessage] = []) {
        self.schemaVersion = schemaVersion
        self.messages = messages
    }
}

public protocol ConversationStore: Sendable {
    func load() async throws -> Conversation
    func save(_ conversation: Conversation) async throws
    func clear() async throws
}

public actor InMemoryConversationStore: ConversationStore {
    private var conversation: Conversation

    public init(_ conversation: Conversation = Conversation()) {
        self.conversation = conversation
    }

    public func load() async throws -> Conversation {
        conversation
    }

    public func save(_ conversation: Conversation) async throws {
        self.conversation = conversation
    }

    public func clear() async throws {
        conversation = Conversation()
    }
}
