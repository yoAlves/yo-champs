import SwiftUI
import YoChampsCore

/// Main-actor projection of the engine for the ask panel. Owns the consumer
/// task so closing the panel tears down the provider stream.
@MainActor
final class CompanionViewModel: ObservableObject {
    /// One transcript round as shown in the panel. Display-only: the engine
    /// owns the real conversation context.
    struct ChatTurn: Identifiable, Equatable {
        let id = UUID()
        let question: String
        var answer: String
        /// True from `ask()` until the engine settles the turn; lets the view
        /// show the waiting indicator immediately, before the async
        /// `.thinking` event arrives.
        var isPending: Bool
    }

    @Published var question = ""
    @Published private(set) var turns: [ChatTurn] = []
    @Published private(set) var state: CompanionState = .idle
    @Published private(set) var errorMessage: String?

    /// Resolved on every action so a profile saved in Settings reaches the
    /// ask path without rebuilding the panel or its window.
    typealias EngineProvider = () -> CompanionEngine

    private let engineProvider: EngineProvider
    private var turn: Task<Void, Never>?

    init(engineProvider: @escaping EngineProvider) {
        self.engineProvider = engineProvider
    }

    convenience init(engine: CompanionEngine) {
        self.init(engineProvider: { engine })
    }

    var isBusy: Bool {
        state == .thinking || state == .streaming
    }

    var canAsk: Bool {
        !isBusy && !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func ask() {
        ask(question)
    }

    func ask(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isBusy else {
            return
        }

        turn?.cancel()
        question = ""
        turns.append(ChatTurn(question: trimmed, answer: "", isPending: true))
        errorMessage = nil
        turn = Task { [weak self] in
            guard let self else {
                return
            }
            let stream = await engineProvider().ask(trimmed)
            for await event in stream {
                handle(event)
            }
        }
    }

    /// Stops the current turn; the engine reports back through `.cancelled`.
    func cancel() {
        guard isBusy else {
            return
        }
        Task { await engineProvider().cancel() }
    }

    func newChat() {
        turn?.cancel()
        turn = nil
        turns = []
        errorMessage = nil
        state = .idle
        Task { [weak self] in
            guard let self else {
                return
            }
            do {
                try await engineProvider().newChat()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Called when the panel closes: abandoning the stream cancels the turn.
    func stop() {
        turn?.cancel()
        turn = nil
        if isBusy {
            state = .idle
        }
        // The consumer task is cancelled, so no `.cancelled` event reaches
        // `handle`; the abandoned turn must not keep the indicator.
        settleLastTurn()
    }

    private func handle(_ event: CompanionEvent) {
        switch event {
        case let .state(newState):
            state = newState
        case let .textDelta(delta):
            if !turns.isEmpty {
                turns[turns.count - 1].answer += delta
            }
        case .completed, .cancelled:
            settleLastTurn()
        case let .failed(message):
            settleLastTurn()
            errorMessage = message
        }
    }

    /// A settled turn no longer shows the waiting indicator, even if it
    /// streamed no text (abandoned, empty or failed answer).
    private func settleLastTurn() {
        if !turns.isEmpty {
            turns[turns.count - 1].isPending = false
        }
    }
}
