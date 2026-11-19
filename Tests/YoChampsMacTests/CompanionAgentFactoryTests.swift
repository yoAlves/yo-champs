import Foundation
import Testing
import YoChampsCore
@testable import YoChampsMac
import YoChampsProviders

@Suite("CompanionAgentFactory")
struct CompanionAgentFactoryTests {
    @Test("carries the profile reasoning effort into the engine agent")
    func carriesReasoningEffort() throws {
        let profile = try ProviderProfile(
            id: "personal-go",
            label: "Personal Go",
            kind: .compatible,
            baseURL: #require(URL(string: "https://example.test/v1")),
            model: "m",
            headers: [:],
            secretRef: "keychain:provider/personal-go",
            capabilities: [.streaming],
            reasoningEffort: "low",
            isDefault: true
        )

        let agent = CompanionAgentFactory.make(profile: profile, systemPrompt: "s")

        #expect(agent.model == "m")
        #expect(agent.reasoningEffort == "low")
    }

    @Test("leaves the effort unset when the profile has none")
    func omitsMissingEffort() throws {
        let profile = try ProviderProfile(
            id: "personal-go",
            label: "Personal Go",
            kind: .compatible,
            baseURL: #require(URL(string: "https://example.test/v1")),
            model: "m",
            headers: [:],
            secretRef: "keychain:provider/personal-go",
            capabilities: [.streaming],
            isDefault: true
        )

        let agent = CompanionAgentFactory.make(profile: profile, systemPrompt: "s")

        #expect(agent.reasoningEffort == nil)
    }
}
