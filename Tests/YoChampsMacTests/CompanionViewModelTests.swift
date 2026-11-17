import Foundation
import Testing
import YoChampsCore
@testable import YoChampsMac

@MainActor
@Suite("CompanionViewModel")
struct CompanionViewModelTests {
    private func makeViewModel(
        _ modes: ScriptedProvider.Mode...
    ) -> CompanionViewModel {
        let engine = CompanionEngine(
            provider: ScriptedProvider(modes),
            agent: AgentDefinition(
                id: "champ",
                name: "Champ",
                systemPrompt: "You are Champ.",
                model: "mock-model"
            )
        )
        return CompanionViewModel(engine: engine)
    }

    /// The view model consumes engine events in its own unstructured task,
    /// so tests poll observable state instead of awaiting the stream.
    private func waitUntil(
        _ condition: () -> Bool,
        timeout: TimeInterval = 5
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(condition(), "condition not met within \(timeout)s")
    }

    @Test("ask appends a turn and streams its answer")
    func askAppendsTurnAndStreamsAnswer() async throws {
        let model = makeViewModel(.reply(["one ", "two"]))

        model.question = "hello"
        model.ask()
        try await waitUntil { model.state == .happy }

        #expect(model.turns.count == 1)
        #expect(model.turns[0].question == "hello")
        #expect(model.turns[0].answer == "one two")
    }

    @Test("a second ask keeps both turns")
    func secondAskKeepsBothTurns() async throws {
        let model = makeViewModel(.reply(["one"]))

        model.question = "first"
        model.ask()
        try await waitUntil { model.state == .happy }

        model.question = "second"
        model.ask()
        // Waiting on the outcome itself: `state` can still be the previous
        // turn's `.happy` right after the synchronous turn append.
        try await waitUntil { model.turns.count == 2 && model.turns[1].answer == "one" }

        #expect(model.turns[0].question == "first")
        #expect(model.turns[0].answer == "one")
        #expect(model.turns[1].question == "second")
        #expect(model.turns[1].answer == "one")
    }

    @Test("an empty answer still completes the turn")
    func emptyAnswerStillCompletes() async throws {
        let model = makeViewModel(.reply([]))

        model.question = "hello"
        model.ask()
        // The engine contract: an empty answer completes with .confused.
        try await waitUntil { model.state == .confused }

        #expect(model.turns.count == 1)
        #expect(model.turns[0].question == "hello")
        #expect(model.turns[0].answer == "")
    }

    @Test("cancelling mid-stream keeps the partial answer and the next ask appends")
    func cancelMidStreamKeepsPartialAndNextAskAppends() async throws {
        let model = makeViewModel(.block(chunk: "part"), .reply(["done"]))

        model.question = "hello"
        model.ask()
        try await waitUntil { !model.turns.isEmpty && model.turns[0].answer == "part" }

        model.cancel()
        try await waitUntil { model.state == .idle }

        #expect(model.turns.count == 1)
        #expect(model.turns[0].answer == "part")

        model.question = "next"
        model.ask()
        try await waitUntil { model.turns.count == 2 && model.state == .happy }

        #expect(model.turns[0].answer == "part")
        #expect(model.turns[1].question == "next")
        #expect(model.turns[1].answer == "done")
    }

    @Test("newChat clears the transcript")
    func newChatClearsTranscript() async throws {
        let model = makeViewModel(.reply(["one"]))

        model.question = "hello"
        model.ask()
        try await waitUntil { model.state == .happy }

        model.newChat()
        try await waitUntil { model.state == .idle }

        #expect(model.turns.isEmpty)
        #expect(model.errorMessage == nil)
    }
}
