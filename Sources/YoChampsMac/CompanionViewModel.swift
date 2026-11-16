import SwiftUI
import YoChampsCore

/// Main-actor projection of the engine for the ask panel. Owns the consumer
/// task so closing the panel tears down the provider stream.
@MainActor
final class CompanionViewModel: ObservableObject {
    @Published var question = ""
    @Published private(set) var answer = ""
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

    var statusLabel: String {
        switch state {
        case .thinking:
            "Thinking…"
        case .streaming:
            "Streaming…"
        case .idle, .happy, .confused, .error:
            ""
        }
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
        answer = ""
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
        answer = ""
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
    }

    private func handle(_ event: CompanionEvent) {
        switch event {
        case let .state(newState):
            state = newState
        case let .textDelta(delta):
            answer += delta
        case .completed, .cancelled:
            break
        case let .failed(message):
            errorMessage = message
        }
    }
}
