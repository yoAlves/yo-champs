import Foundation

/// Owns the conversation loop: builds context, streams from the provider,
/// records state transitions and stores completed turns. One turn at a time.
public actor CompanionEngine {
    private let provider: any LLMProvider
    private let agent: AgentDefinition
    private let store: any ConversationStore
    private let contextBuilder: any ContextBuilder
    private let budget: ContextBudget

    private var active: (id: Int, task: Task<Void, Never>)?
    private var lastTurnID = 0

    public init(
        provider: any LLMProvider,
        agent: AgentDefinition,
        store: any ConversationStore = InMemoryConversationStore(),
        contextBuilder: any ContextBuilder = DefaultContextBuilder(),
        budget: ContextBudget = .default
    ) {
        self.provider = provider
        self.agent = agent
        self.store = store
        self.contextBuilder = contextBuilder
        self.budget = budget
    }

    /// Starts a turn. A previous in-flight turn is cancelled first.
    public func ask(_ question: String) -> AsyncStream<CompanionEvent> {
        active?.task.cancel()

        lastTurnID += 1
        let turnID = lastTurnID
        let (stream, continuation) = AsyncStream.makeStream(of: CompanionEvent.self)

        let task = Task {
            await self.run(question, turnID: turnID, emit: continuation)
        }
        active = (turnID, task)

        // A consumer that stops iterating (panel closed, task cancelled) must
        // not leave the provider streaming in the background.
        continuation.onTermination = { [weak self] _ in
            Task { await self?.cancelTurn(turnID) }
        }
        return stream
    }

    public func cancel() {
        active?.task.cancel()
    }

    /// Drops the stored conversation. An in-flight turn is cancelled so it
    /// cannot write into the new chat.
    public func newChat() async throws {
        active?.task.cancel()
        try await store.clear()
    }

    private func cancelTurn(_ id: Int) {
        guard active?.id == id else {
            return
        }
        active?.task.cancel()
    }

    private func run(
        _ question: String,
        turnID: Int,
        emit: AsyncStream<CompanionEvent>.Continuation
    ) async {
        emit.yield(.state(.thinking))

        do {
            let conversation = try await store.load()
            let messages = contextBuilder.build(
                systemPrompt: agent.systemPrompt,
                history: conversation.messages,
                question: question,
                budget: budget
            )
            let request = LLMRequest(
                model: agent.model,
                messages: messages,
                reasoningEffort: agent.reasoningEffort
            )

            var answer = ""
            var isStreaming = false
            for try await event in provider.stream(request) {
                switch event {
                case let .textDelta(delta):
                    if !isStreaming {
                        isStreaming = true
                        emit.yield(.state(.streaming))
                    }
                    answer += delta
                    emit.yield(.textDelta(delta))
                case .usage, .done:
                    break
                }
            }
            // A cancelled iterator can end without throwing; this catches it
            // before the turn is written.
            try Task.checkCancellation()

            var updated = conversation
            updated.messages.append(LLMMessage(role: .user, content: question))
            updated.messages.append(LLMMessage(role: .assistant, content: answer))
            try await store.save(updated)

            let finalState: CompanionState = answer
                .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .confused : .happy
            emit.yield(.state(finalState))
            emit.yield(.completed)
        } catch is CancellationError {
            emit.yield(.state(.idle))
            emit.yield(.cancelled)
        } catch {
            emit.yield(.state(.error))
            emit.yield(.failed(Self.displayMessage(for: error)))
        }

        emit.finish()
        if active?.id == turnID {
            active = nil
        }
    }

    private static func displayMessage(for error: Error) -> String {
        if let llmError = error as? LLMError {
            return llmError.description
        }
        return error.localizedDescription
    }
}
