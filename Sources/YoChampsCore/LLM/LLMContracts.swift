import Foundation

public struct LLMMessage: Codable, Sendable, Equatable {
    public enum Role: String, Codable, Sendable, CaseIterable {
        case system
        case developer
        case user
        case assistant
    }

    public let role: Role
    public let content: String

    public init(role: Role, content: String) {
        self.role = role
        self.content = content
    }
}

public struct LLMRequest: Codable, Sendable, Equatable {
    public let model: String
    public let messages: [LLMMessage]
    public let maxTokens: Int?
    public let temperature: Double?
    public let headers: [String: String]

    public init(
        model: String,
        messages: [LLMMessage],
        maxTokens: Int? = nil,
        temperature: Double? = nil,
        headers: [String: String] = [:]
    ) {
        self.model = model
        self.messages = messages
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.headers = headers
    }
}

public struct LLMUsage: Codable, Sendable, Equatable {
    public let promptTokens: Int?
    public let completionTokens: Int?

    public init(promptTokens: Int? = nil, completionTokens: Int? = nil) {
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
    }
}

public enum LLMEvent: Sendable, Equatable {
    case textDelta(String)
    case usage(LLMUsage)
    case done
}

public enum LLMError: Error, Sendable, Equatable, CustomStringConvertible {
    case provider(String)
    case emptyResponse
    case invalidRequest(String)
    case unauthorized
    case invalidModel(String)
    case rateLimited
    case timedOut
    case server(status: Int)

    public var description: String {
        switch self {
        case let .provider(message):
            "provider error: \(message)"
        case .emptyResponse:
            "provider returned an empty response"
        case let .invalidRequest(message):
            "invalid request: \(message)"
        case .unauthorized:
            "the API key is missing or rejected; check the provider key"
        case let .invalidModel(model):
            "the model \"\(model)\" is unavailable; check the profile model"
        case .rateLimited:
            "rate limited by the provider; try again shortly"
        case .timedOut:
            "the provider timed out; try again"
        case let .server(status):
            "the provider returned server error \(status); try again"
        }
    }
}

public protocol LLMProvider: Sendable {
    func stream(_ request: LLMRequest) -> AsyncThrowingStream<LLMEvent, Error>
}
