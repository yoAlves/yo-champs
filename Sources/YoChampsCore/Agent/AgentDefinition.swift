import Foundation

public struct AgentDefinition: Codable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let systemPrompt: String
    public let model: String
    public let style: String?

    public init(
        id: String,
        name: String,
        systemPrompt: String,
        model: String,
        style: String? = nil
    ) {
        self.id = id
        self.name = name
        self.systemPrompt = systemPrompt
        self.model = model
        self.style = style
    }
}
