import Testing
@testable import YoChampsCore

@Suite("ContextBuilder")
struct ContextBuilderTests {
    private let builder = DefaultContextBuilder()

    private func turns(_ count: Int) -> [LLMMessage] {
        (0 ..< count).flatMap { index in
            [
                LLMMessage(role: .user, content: "q\(index)"),
                LLMMessage(role: .assistant, content: "a\(index)"),
            ]
        }
    }

    @Test("system first, current question last, history in between")
    func order() {
        let messages = builder.build(
            systemPrompt: "system",
            history: turns(1),
            question: "now",
            budget: ContextBudget(maxTurns: 12, maxCharacters: 6000)
        )
        #expect(messages.map(\.content) == ["system", "q0", "a0", "now"])
        #expect(messages.first?.role == .system)
        #expect(messages.last?.role == .user)
    }

    @Test("keeps only the most recent maxTurns pairs")
    func maxTurns() {
        let messages = builder.build(
            systemPrompt: "system",
            history: turns(20),
            question: "now",
            budget: ContextBudget(maxTurns: 12, maxCharacters: 100_000)
        )
        let history = Array(messages.dropFirst().dropLast())
        #expect(history.count == 24)
        #expect(history.first?.content == "q8")
        #expect(history.last?.content == "a19")
    }

    @Test("drops the oldest turns to fit the character budget")
    func characterBudget() {
        let history = [
            LLMMessage(role: .user, content: "u"),
            LLMMessage(role: .assistant, content: "a"),
            LLMMessage(role: .user, content: "u"),
            LLMMessage(role: .assistant, content: "a"),
            LLMMessage(role: .user, content: "u"),
            LLMMessage(role: .assistant, content: "a"),
        ]
        let messages = builder.build(
            systemPrompt: "s",
            history: history,
            question: "q",
            budget: ContextBudget(maxTurns: 12, maxCharacters: 6)
        )
        // system (1) + question (1) + two turns (2 each) = 6 characters.
        #expect(messages.count == 6)
    }

    @Test("system and current question survive a tiny budget")
    func tinyBudget() {
        let messages = builder.build(
            systemPrompt: "system",
            history: turns(3),
            question: "question",
            budget: ContextBudget(maxTurns: 12, maxCharacters: 1)
        )
        #expect(messages.map(\.content) == ["system", "question"])
    }

    @Test("ignores malformed history instead of crashing")
    func malformedHistory() {
        let history = [
            LLMMessage(role: .assistant, content: "orphan"),
            LLMMessage(role: .user, content: "u"),
            LLMMessage(role: .assistant, content: "a"),
        ]
        let messages = builder.build(
            systemPrompt: "",
            history: history,
            question: "q",
            budget: ContextBudget(maxTurns: 12, maxCharacters: 6000)
        )
        #expect(messages.map(\.content) == ["u", "a", "q"])
    }
}
