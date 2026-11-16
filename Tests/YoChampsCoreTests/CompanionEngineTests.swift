import Foundation
import Testing
@testable import YoChampsCore

@Suite("CompanionEngine")
struct CompanionEngineTests {
    private let agent = AgentDefinition(
        id: "champ",
        name: "Champ",
        systemPrompt: "You are Champ.",
        model: "mock-model"
    )

    private func makeEngine(
        _ behavior: SpyProvider.Behavior,
        store: any ConversationStore = InMemoryConversationStore(),
        budget: ContextBudget = .default
    ) -> (CompanionEngine, RequestRecorder) {
        let recorder = RequestRecorder()
        let engine = CompanionEngine(
            provider: SpyProvider(recorder: recorder, behavior: behavior),
            agent: agent,
            store: store,
            budget: budget
        )
        return (engine, recorder)
    }

    @Test("success emits thinking, streaming, deltas, happy and completed")
    func success() async throws {
        let store = InMemoryConversationStore()
        let (engine, _) = makeEngine(.reply(["one ", "two"]), store: store)

        let stream = await engine.ask("hello")
        var events: [CompanionEvent] = []
        for await event in stream {
            events.append(event)
        }

        #expect(events == [
            .state(.thinking),
            .state(.streaming),
            .textDelta("one "),
            .textDelta("two"),
            .state(.happy),
            .completed,
        ])
        let conversation = try await store.load()
        #expect(conversation.messages == [
            LLMMessage(role: .user, content: "hello"),
            LLMMessage(role: .assistant, content: "one two"),
        ])
    }

    @Test("the second turn carries the first turn in its request")
    func contextIncludesHistory() async {
        let (engine, recorder) = makeEngine(.reply(["one"]))

        let firstStream = await engine.ask("first")
        for await _ in firstStream {}
        let secondStream = await engine.ask("second")
        for await _ in secondStream {}

        let requests = recorder.requests
        #expect(requests.count == 2)
        #expect(requests[0].model == "mock-model")
        #expect(requests[1].messages == [
            LLMMessage(role: .system, content: "You are Champ."),
            LLMMessage(role: .user, content: "first"),
            LLMMessage(role: .assistant, content: "one"),
            LLMMessage(role: .user, content: "second"),
        ])
    }

    @Test("cancel returns to idle and drops the turn", .timeLimit(.minutes(1)))
    func cancel() async throws {
        let store = InMemoryConversationStore()
        let (engine, _) = makeEngine(.blockingReply(["one ", "two"]), store: store)
        let recorder = EventRecorder()
        let firstDelta = TextDeltaSignal()

        let stream = await engine.ask("hello")
        let consumer = Task {
            for await event in stream {
                await recorder.append(event)
                if case .textDelta = event {
                    await firstDelta.fire()
                }
            }
        }

        await firstDelta.wait()
        await engine.cancel()
        await consumer.value

        let events = await recorder.events
        #expect(events == [
            .state(.thinking),
            .state(.streaming),
            .textDelta("one "),
            .state(.idle),
            .cancelled,
        ])
        let conversation = try await store.load()
        #expect(conversation.messages.isEmpty)
    }

    @Test("starting a new turn cancels the previous one", .timeLimit(.minutes(1)))
    func newTurnCancelsPrevious() async {
        let (engine, _) = makeEngine(.blockingReply(["one ", "two"]))
        let recorder = EventRecorder()
        let firstDelta = TextDeltaSignal()

        let oldStream = await engine.ask("first")
        let oldConsumer = Task {
            for await event in oldStream {
                await recorder.append(event)
                if case .textDelta = event {
                    await firstDelta.fire()
                }
            }
        }
        await firstDelta.wait()

        let newStream = await engine.ask("second")
        await oldConsumer.value

        let events = await recorder.events
        #expect(events == [
            .state(.thinking),
            .state(.streaming),
            .textDelta("one "),
            .state(.idle),
            .cancelled,
        ])

        await engine.cancel()
        for await _ in newStream {}
    }

    @Test("abandoning the stream cancels the provider turn", .timeLimit(.minutes(1)))
    func abandonedStreamCancelsProvider() async {
        let termination = TerminationRecorder()
        let provider = SpyProvider(
            behavior: .blockingReply(["one ", "two"]),
            termination: termination
        )
        let engine = CompanionEngine(
            provider: provider,
            agent: agent,
            store: InMemoryConversationStore()
        )
        let firstDelta = TextDeltaSignal()

        let stream = await engine.ask("hello")
        let consumer = Task {
            for await event in stream {
                if case .textDelta = event {
                    await firstDelta.fire()
                }
            }
        }
        await firstDelta.wait()
        consumer.cancel()
        await termination.wait()
        await consumer.value
    }

    @Test("provider failure emits the error state and a displayable message")
    func failure() async throws {
        let store = InMemoryConversationStore()
        let (engine, _) = makeEngine(.failure(.provider("boom")), store: store)

        let stream = await engine.ask("hello")
        var events: [CompanionEvent] = []
        for await event in stream {
            events.append(event)
        }

        #expect(events == [
            .state(.thinking),
            .state(.error),
            .failed("provider error: boom"),
        ])
        let conversation = try await store.load()
        #expect(conversation.messages.isEmpty)
    }

    @Test("new chat clears context without restarting the engine")
    func newChatClearsContext() async throws {
        let (engine, recorder) = makeEngine(.reply(["one"]))

        let firstStream = await engine.ask("first")
        for await _ in firstStream {}
        try await engine.newChat()
        let secondStream = await engine.ask("second")
        for await _ in secondStream {}

        let requests = recorder.requests
        #expect(requests[1].messages == [
            LLMMessage(role: .system, content: "You are Champ."),
            LLMMessage(role: .user, content: "second"),
        ])
    }
}
