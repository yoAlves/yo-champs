import Foundation

public protocol AgentRegistry: Sendable {
    func agent(id: String) -> AgentDefinition?
    func defaultAgent() -> AgentDefinition
}

/// Data-driven registry. Ids must be unique and the default must resolve at
/// construction time so lookups never disagree about which agent is default.
public struct StaticAgentRegistry: AgentRegistry {
    private let agentsByID: [String: AgentDefinition]
    private let configuredDefault: AgentDefinition

    public init?(agents: [AgentDefinition], defaultID: String) {
        let ids = agents.map(\.id)
        guard Set(ids).count == ids.count, let configuredDefault = agents.first(where: { $0.id == defaultID }) else {
            return nil
        }
        var agentsByID: [String: AgentDefinition] = [:]
        for agent in agents {
            agentsByID[agent.id] = agent
        }
        self.agentsByID = agentsByID
        self.configuredDefault = configuredDefault
    }

    public func agent(id: String) -> AgentDefinition? {
        agentsByID[id]
    }

    public func defaultAgent() -> AgentDefinition {
        configuredDefault
    }
}
