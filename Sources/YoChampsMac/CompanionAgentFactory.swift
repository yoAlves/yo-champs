import YoChampsCore

/// The app's only production agent: the Ask flow builds it from the selected
/// profile so the model and the optional reasoning effort travel together.
enum CompanionAgentFactory {
    static func make(profile: ProviderProfile, systemPrompt: String) -> AgentDefinition {
        AgentDefinition(
            id: profile.id,
            name: profile.label,
            systemPrompt: systemPrompt,
            model: profile.model,
            reasoningEffort: profile.reasoningEffort
        )
    }
}
