import Foundation
@testable import YoChampsProviders

/// Queues canned HTTP results so provider tests never touch the network.
actor FakeTransport: LLMHTTPTransport {
    private var queued: [Result<LLMHTTPResponse, Error>] = []
    private(set) var requests: [LLMHTTPRequest] = []

    func enqueue(status: Int, sse: String) async {
        let body = AsyncThrowingStream<UInt8, Error> { continuation in
            for byte in Array(sse.utf8) {
                continuation.yield(byte)
            }
            continuation.finish()
        }
        await enqueue(status: status, body: body)
    }

    func enqueue(status: Int, body: AsyncThrowingStream<UInt8, Error>) async {
        queued.append(.success(LLMHTTPResponse(statusCode: status, body: body)))
    }

    func enqueue(error: Error) async {
        queued.append(.failure(error))
    }

    func send(_ request: LLMHTTPRequest) async throws -> LLMHTTPResponse {
        requests.append(request)
        guard !queued.isEmpty else {
            throw LLMTransportError.connection("no queued response")
        }
        return try queued.removeFirst().get()
    }
}
