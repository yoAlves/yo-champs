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

        var events: [LLMEvent] = []
        for try await event in provider.stream(request) {
            events.append(event)
        }

        let deltas = events.compactMap { event -> String? in
            guard case let .textDelta(delta) = event else { return nil }
            return delta
        }
        #expect(deltas == ["one ", "two ", "three"])
        #expect(deltas.joined() == "one two three")
        #expect(events.last == .done)
        #expect(events.filter { $0 == .done }.count == 1)
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
        let provider = MockProvider(behavior: .failure(.provider("boom")))

        var deltas: [String] = []
        var caught: LLMError?
        do {
            for try await event in provider.stream(request) {
                if case let .textDelta(delta) = event {
                    deltas.append(delta)
                }
            }
        } catch {
            caught = error as? LLMError
        }

        #expect(caught == LLMError.provider("boom"))
        #expect(deltas.isEmpty)
    }

    @Test("an empty reply surfaces emptyResponse")
    func emptyReply() async {
        let provider = MockProvider(behavior: .reply(""))

        var caught: LLMError?
        do {
            for try await _ in provider.stream(request) {}
        } catch {
            caught = error as? LLMError
        }

        #expect(caught == LLMError.emptyResponse)
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
