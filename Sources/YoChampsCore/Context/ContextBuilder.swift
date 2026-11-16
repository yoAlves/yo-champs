import Foundation

public struct ContextBudget: Sendable, Equatable {
    public static let `default` = ContextBudget(maxTurns: 12, maxCharacters: 6000)

    public let maxTurns: Int
    public let maxCharacters: Int

    public init(maxTurns: Int = 12, maxCharacters: Int = 6000) {
        precondition(maxTurns > 0, "maxTurns must be positive")
        precondition(maxCharacters > 0, "maxCharacters must be positive")
        self.maxTurns = maxTurns
        self.maxCharacters = maxCharacters
    }
}

public protocol ContextBuilder: Sendable {
    func build(
        systemPrompt: String,
        history: [LLMMessage],
        question: String,
        budget: ContextBudget
    ) -> [LLMMessage]
}

/// Keeps the stable system prompt and the current question, then fills the
/// budget with the most recent complete user/assistant turns.
public struct DefaultContextBuilder: ContextBuilder {
    public init() {}

    public func build(
        systemPrompt: String,
        history: [LLMMessage],
        question: String,
        budget: ContextBudget
    ) -> [LLMMessage] {
        var messages: [LLMMessage] = []
        let system = systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !system.isEmpty {
            messages.append(LLMMessage(role: .system, content: systemPrompt))
        }

        let current = LLMMessage(role: .user, content: question)
        var used = messages.reduce(0) { $0 + $1.content.count } + current.content.count

        let recentTurns = completeTurns(from: history).suffix(budget.maxTurns)
        var selected: [[LLMMessage]] = []
        for turn in recentTurns.reversed() {
            let cost = turn.reduce(0) { $0 + $1.content.count }
            if used + cost > budget.maxCharacters {
                break
            }
            selected.append(turn)
            used += cost
        }

        messages.append(contentsOf: selected.reversed().flatMap(\.self))
        messages.append(current)
        return messages
    }

    private func completeTurns(from history: [LLMMessage]) -> [[LLMMessage]] {
        var turns: [[LLMMessage]] = []
        var index = 0
        while index + 1 < history.count {
            let user = history[index]
            let assistant = history[index + 1]
            if user.role == .user, assistant.role == .assistant {
                turns.append([user, assistant])
                index += 2
            } else {
                index += 1
            }
        }
        return turns
    }
}
