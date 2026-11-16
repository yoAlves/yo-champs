import Foundation
import Testing
import YoChampsCore
@testable import YoChampsProviders

@Suite("OpenAI-compatible provider")
struct OpenAICompatibleProviderTests {
    private let request = LLMRequest(
        model: "test-model",
        messages: [LLMMessage(role: .user, content: "hello")],
        headers: ["X-Test": "yes"]
    )

    private func makeProvider(
        transport: FakeTransport,
        clock: any Clock = RecordingClock(),
        maxRetries: Int = 0
    ) -> OpenAICompatibleProvider {
        let configuration = OpenAICompatibleProvider.Configuration(
            baseURL: URL(string: "https://example.test/v1")!,
            maxRetries: maxRetries,
            retryDelay: .milliseconds(250),
            timeout: .seconds(5)
        )
        return OpenAICompatibleProvider(
            configuration: configuration,
            transport: transport,
            clock: clock
        )
    }

    private func delta(_ text: String) -> String {
        "data: {\"choices\":[{\"delta\":{\"content\":\"\(text)\"},\"finish_reason\":null}]}\n\n"
    }

    private let done = "data: [DONE]\n\n"

    @Test("streams SSE deltas and builds a chat completion request")
    func streamsAnswer() async throws {
        let transport = FakeTransport()
        await transport.enqueue(status: 200, sse: delta("Hello ") + delta("world") + done)
        let provider = makeProvider(transport: transport)

        try await ProviderContract.streamsAnswer(
            provider,
            request: request,
            expectedDeltas: ["Hello ", "world"]
        )

        let requests = await transport.requests
        #expect(requests.count == 1)
        #expect(requests[0].url.absoluteString == "https://example.test/v1/chat/completions")
        #expect(requests[0].headers["X-Test"] == "yes")
        let body = requests[0].body
        let object = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        #expect(object?["model"] as? String == "test-model")
        #expect(object?["stream"] as? Bool == true)
        #expect((object?["messages"] as? [[String: Any]])?.count == 1)
    }

    @Test("maps HTTP status codes to distinct domain errors")
    func statusMapping() async {
        let cases: [(Int, LLMError)] = [
            (401, .unauthorized),
            (403, .unauthorized),
            (404, .invalidModel("test-model")),
            (408, .timedOut),
            (429, .rateLimited),
            (400, .invalidRequest("invalid request")),
        ]
        for (status, expected) in cases {
            let transport = FakeTransport()
            await transport.enqueue(status: status, sse: "")
            await ProviderContract.failure(
                makeProvider(transport: transport),
                request: request,
                expected: expected
            )
        }
    }

    @Test("retries server errors through the injected clock")
    func retriesServerErrors() async throws {
        let transport = FakeTransport()
        await transport.enqueue(status: 503, sse: "")
        await transport.enqueue(status: 200, sse: delta("ok") + done)
        let clock = RecordingClock()

        try await ProviderContract.streamsAnswer(
            makeProvider(transport: transport, clock: clock, maxRetries: 1),
            request: request,
            expectedDeltas: ["ok"]
        )

        let requests = await transport.requests
        let sleeps = await clock.sleeps
        #expect(requests.count == 2)
        #expect(sleeps == [.milliseconds(250)])
    }

    @Test("exhausted retries surface the server status")
    func exhaustedRetries() async {
        let transport = FakeTransport()
        await transport.enqueue(status: 500, sse: "")
        await transport.enqueue(status: 500, sse: "")

        await ProviderContract.failure(
            makeProvider(transport: transport, maxRetries: 1),
            request: request,
            expected: .server(status: 500)
        )
    }

    @Test("transport timeouts surface as timedOut")
    func transportTimeout() async {
        let transport = FakeTransport()
        await transport.enqueue(error: LLMTransportError.timedOut)
        await transport.enqueue(error: LLMTransportError.timedOut)

        await ProviderContract.failure(
            makeProvider(transport: transport, maxRetries: 1),
            request: request,
            expected: .timedOut
        )
    }

    @Test("a stream with no deltas surfaces emptyResponse")
    func emptyStream() async {
        let transport = FakeTransport()
        await transport.enqueue(status: 200, sse: done)
        await ProviderContract.emptyResponse(
            makeProvider(transport: transport),
            request: request
        )
    }

    @Test("malformed payloads do not echo provider text")
    func malformedPayload() async {
        let transport = FakeTransport()
        await transport.enqueue(status: 200, sse: "data: secret-body-should-not-leak\n\n")

        await ProviderContract.failure(
            makeProvider(transport: transport),
            request: request,
            expected: .provider("invalid streaming payload")
        )
    }

    @Test("emits deltas before the body closes")
    func streamsIncrementally() async throws {
        let (body, bodyContinuation) = AsyncThrowingStream<UInt8, Error>.makeStream()
        let transport = FakeTransport()
        await transport.enqueue(status: 200, body: body)
        let provider = makeProvider(transport: transport)
        let recorder = DeltaRecorder()

        let consumer = Task {
            for try await event in provider.stream(request) {
                if case let .textDelta(delta) = event {
                    await recorder.append(delta)
                }
            }
        }

        for byte in Array(delta("a").utf8) {
            bodyContinuation.yield(byte)
        }
        var sawFirst = false
        for _ in 0 ..< 20 {
            if await !(recorder.deltas).isEmpty {
                sawFirst = true
                break
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        #expect(sawFirst)

        for byte in Array((delta("b") + done).utf8) {
            bodyContinuation.yield(byte)
        }
        bodyContinuation.finish()
        try await consumer.value

        let deltas = await recorder.deltas
        #expect(deltas == ["a", "b"])
    }

    @Test("cancellation is not retried")
    func cancellationIsNotRetried() async {
        let transport = FakeTransport()
        await transport.enqueue(error: CancellationError())
        let provider = makeProvider(transport: transport, clock: RecordingClock(), maxRetries: 2)

        var caught: Error?
        do {
            for try await _ in provider.stream(request) {}
        } catch {
            caught = error
        }

        let requests = await transport.requests
        #expect(caught is CancellationError)
        #expect(requests.count == 1)
    }

    @Test("rate limits surface without retrying")
    func rateLimitIsNotRetried() async {
        let transport = FakeTransport()
        await transport.enqueue(status: 429, sse: "")
        await transport.enqueue(status: 200, sse: delta("ok") + done)

        await ProviderContract.failure(
            makeProvider(transport: transport, maxRetries: 2),
            request: request,
            expected: .rateLimited
        )

        let requests = await transport.requests
        #expect(requests.count == 1)
    }

    @Test("configured timeout reaches the transport")
    func timeoutReachesTransport() async throws {
        let transport = FakeTransport()
        await transport.enqueue(status: 200, sse: delta("ok") + done)
        try await ProviderContract.streamsAnswer(
            makeProvider(transport: transport),
            request: request,
            expectedDeltas: ["ok"]
        )

        let requests = await transport.requests
        #expect(requests[0].timeout == .seconds(5))
    }

    @Test("chunks without delta content do not abort the answer")
    func chunkWithoutDelta() async throws {
        let transport = FakeTransport()
        let metadata = "data: {\"choices\":[{\"index\":0,\"finish_reason\":null}]}\n\n"
        await transport.enqueue(status: 200, sse: metadata + delta("ok") + done)

        try await ProviderContract.streamsAnswer(
            makeProvider(transport: transport),
            request: request,
            expectedDeltas: ["ok"]
        )
    }
}
