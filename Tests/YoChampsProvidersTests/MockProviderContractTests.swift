import Foundation
import Testing
import YoChampsCore
@testable import YoChampsProviders

@Suite("MockProvider contract")
struct MockProviderContractTests {
    private let request = LLMRequest(
        model: "mock-model",
        messages: [LLMMessage(role: .user, content: "hello")]
    )

    @Test("streams ordered deltas that rebuild the answer, then done")
    func streamsAnswer() async throws {
        let provider = MockProvider(
            behavior: .reply("one two three"),
            chunkDelay: .milliseconds(1),
            clock: RecordingClock()
        )

        try await ProviderContract.streamsAnswer(
            provider,
            request: request,
            expectedDeltas: ["one ", "two ", "three"]
        )
    }

    @Test("paces chunks through the injected clock")
    func pacesChunks() async throws {
        let clock = RecordingClock()
        let provider = MockProvider(
            behavior: .reply("a b c"),
            chunkDelay: .milliseconds(25),
            clock: clock
        )

        for try await _ in provider.stream(request) {}

        let sleeps = await clock.sleeps
        #expect(sleeps == [.milliseconds(25), .milliseconds(25)])
    }

    @Test("default behavior replies with the default answer")
    func defaultReply() async throws {
        var text = ""
        for try await event in MockProvider().stream(request) {
            if case let .textDelta(delta) = event {
                text += delta
            }
        }
        #expect(text == MockProvider.defaultAnswer)
    }

    @Test("provider failures surface without emitting text")
    func failurePropagates() async {
        await ProviderContract.failure(
            MockProvider(behavior: .failure(.provider("boom"))),
            request: request,
            expected: .provider("boom")
        )
    }

    @Test("an empty reply surfaces emptyResponse")
    func emptyReply() async {
        await ProviderContract.emptyResponse(
            MockProvider(behavior: .reply("")),
            request: request
        )
    }

    @Test("cancelling the consumer stops the stream", .timeLimit(.minutes(1)))
    func cancellationStopsStream() async throws {
        let streamRequest = request
        let clock = BlockingClock()
        let provider = MockProvider(
            behavior: .reply("one two three"),
            chunkDelay: .milliseconds(10),
            clock: clock
        )
        let recorder = DeltaRecorder()
        let firstDelta = FirstDeltaSignal()

        let consumer = Task {
            for try await event in provider.stream(streamRequest) {
                if case let .textDelta(delta) = event {
                    await recorder.append(delta)
                    await firstDelta.fire()
                }
            }
        }

        await firstDelta.wait()
        consumer.cancel()
        // Proves `onTermination` cancelled the producer task; otherwise this
        // waits until the test time limit.
        await clock.waitForCancellation()

        do {
            try await consumer.value
        } catch {
            #expect(error is CancellationError)
        }

        let deltas = await recorder.deltas
        #expect(deltas == ["one "])
    }
}
