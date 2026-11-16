import Testing
@testable import YoChampsCore

@Suite("Agent registry")
struct AgentRegistryTests {
    @Test("registry resolves agents by id and exposes the configured default")
    func lookups() throws {
        let champ = AgentDefinition(
            id: "champ",
            name: "Champ",
            systemPrompt: "Be brief.",
            model: "test-model"
        )
        let other = AgentDefinition(
            id: "other",
            name: "Other",
            systemPrompt: "Be verbose.",
            model: "test-model"
        )
        let registry = try #require(StaticAgentRegistry(agents: [champ, other], defaultID: "champ"))

        #expect(registry.agent(id: "champ") == champ)
        #expect(registry.agent(id: "other") == other)
        #expect(registry.agent(id: "missing") == nil)
        #expect(registry.defaultAgent() == champ)
    }

    @Test("registry refuses duplicate agent ids")
    func rejectsDuplicateIDs() {
        let first = AgentDefinition(
            id: "champ",
            name: "First",
            systemPrompt: "Be brief.",
            model: "test-model"
        )
        let second = AgentDefinition(
            id: "champ",
            name: "Second",
            systemPrompt: "Be verbose.",
            model: "test-model"
        )
        #expect(StaticAgentRegistry(agents: [first, second], defaultID: "champ") == nil)
    }

    @Test("registry refuses a default id that is not registered")
    func rejectsUnknownDefault() {
        let champ = AgentDefinition(
            id: "champ",
            name: "Champ",
            systemPrompt: "Be brief.",
            model: "test-model"
        )
        #expect(StaticAgentRegistry(agents: [champ], defaultID: "missing") == nil)
        #expect(StaticAgentRegistry(agents: [], defaultID: "champ") == nil)
    }
}
