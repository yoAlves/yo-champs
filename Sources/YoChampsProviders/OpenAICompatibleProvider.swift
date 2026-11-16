import Foundation
import YoChampsCore

public struct LLMHTTPRequest: Sendable, Equatable {
    public let url: URL
    public let headers: [String: String]
    public let body: Data
    public let timeout: Duration

    public init(url: URL, headers: [String: String], body: Data, timeout: Duration) {
        self.url = url
        self.headers = headers
        self.body = body
        self.timeout = timeout
    }
}

public struct LLMHTTPResponse: Sendable {
    public let statusCode: Int
    public let body: AsyncThrowingStream<UInt8, Error>

    public init(statusCode: Int, body: AsyncThrowingStream<UInt8, Error>) {
        self.statusCode = statusCode
        self.body = body
    }
}

public enum LLMTransportError: Error, Sendable, Equatable {
    case timedOut
    case connection(String)
}

/// The network boundary is injected: the provider owns protocol logic only,
/// so it stays deterministic and builds on every platform (including Linux).
public protocol LLMHTTPTransport: Sendable {
    func send(_ request: LLMHTTPRequest) async throws -> LLMHTTPResponse
}

private enum Retryable: Error {
    case server(Int)
}

private struct ChatRequest: Encodable {
    let model: String
    let messages: [LLMMessage]
    let stream: Bool
    let maxTokens: Int?
    let temperature: Double?

    enum CodingKeys: String, CodingKey {
        case model, messages, stream
        case maxTokens = "max_tokens"
        case temperature
    }
}

private struct ChatChunk: Decodable {
    let choices: [ChatChoice]
}

private struct ChatChoice: Decodable {
    let delta: ChatDelta?
}

private struct ChatDelta: Decodable {
    let content: String?
}

/// Streams an OpenAI-compatible chat-completions endpoint as `LLMEvent`s.
/// Headers (including the Keychain-backed key) come from the request; this
/// type never stores credentials.
public struct OpenAICompatibleProvider: LLMProvider {
    public struct Configuration: Sendable, Equatable {
        public let baseURL: URL
        public let maxRetries: Int
        public let retryDelay: Duration
        public let timeout: Duration

        public init(
            baseURL: URL,
            maxRetries: Int = 2,
            retryDelay: Duration = .milliseconds(250),
            timeout: Duration = .seconds(30)
        ) {
            self.baseURL = baseURL
            self.maxRetries = maxRetries
            self.retryDelay = retryDelay
            self.timeout = timeout
        }
    }

    private let configuration: Configuration
    private let transport: any LLMHTTPTransport
    private let clock: any Clock

    public init(
        configuration: Configuration,
        transport: any LLMHTTPTransport,
        clock: any Clock = SystemClock()
    ) {
        self.configuration = configuration
        self.transport = transport
        self.clock = clock
    }

    public func stream(_ request: LLMRequest) -> AsyncThrowingStream<LLMEvent, Error> {
        let configuration = configuration
        let transport = transport
        let clock = clock

        return AsyncThrowingStream { continuation in
            let producer = Task {
                do {
                    try Task.checkCancellation()
                    let httpRequest = try Self.httpRequest(for: request, configuration: configuration)
                    let response = try await Self.sendWithRetry(
                        httpRequest,
                        transport: transport,
                        clock: clock,
                        configuration: configuration
                    )
                    try Task.checkCancellation()
                    try Self.mapStatus(response.statusCode, model: request.model)
                    try await Self.consume(response.body, into: continuation)
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: CancellationError())
                } catch {
                    continuation.finish(throwing: Self.map(error))
                }
            }
            continuation.onTermination = { _ in producer.cancel() }
        }
    }

    private static func consume(
        _ body: AsyncThrowingStream<UInt8, Error>,
        into continuation: AsyncThrowingStream<LLMEvent, Error>.Continuation
    ) async throws {
        var decoder = SSEDecoder()
        var buffer: [UInt8] = []
        var hasContent = false

        func handle(_ events: [SSEEvent]) throws {
            for event in events {
                switch event {
                case .done:
                    break
                case let .data(payload):
                    guard let chunk = try? JSONDecoder().decode(
                        ChatChunk.self,
                        from: Data(payload.utf8)
                    ) else {
                        throw LLMError.provider("invalid streaming payload")
                    }
                    for choice in chunk.choices {
                        if let content = choice.delta?.content, !content.isEmpty {
                            hasContent = true
                            continuation.yield(.textDelta(content))
                        }
                    }
                }
            }
        }

        for try await byte in body {
            try Task.checkCancellation()
            buffer.append(byte)
            // Flush per line so deltas reach the UI while the answer streams.
            if byte == 0x0A || buffer.count >= 4096 {
                try handle(decoder.feed(buffer))
                buffer.removeAll(keepingCapacity: true)
            }
        }
        try handle(decoder.feed(buffer))
        try handle(decoder.finish())
        guard hasContent else {
            throw LLMError.emptyResponse
        }
        // Terminal event last, and never before validation succeeded.
        continuation.yield(.done)
    }

    private static func httpRequest(
        for request: LLMRequest,
        configuration: Configuration
    ) throws -> LLMHTTPRequest {
        let body = ChatRequest(
            model: request.model,
            messages: request.messages,
            stream: true,
            maxTokens: request.maxTokens,
            temperature: request.temperature
        )
        let data = try JSONEncoder().encode(body)
        var headers = ["Content-Type": "application/json"]
        for (key, value) in request.headers {
            headers[key] = value
        }
        return LLMHTTPRequest(
            url: configuration.baseURL.appendingPathComponent("chat/completions"),
            headers: headers,
            body: data,
            timeout: configuration.timeout
        )
    }

    private static func sendWithRetry(
        _ request: LLMHTTPRequest,
        transport: any LLMHTTPTransport,
        clock: any Clock,
        configuration: Configuration
    ) async throws -> LLMHTTPResponse {
        var attempt = 0
        while true {
            do {
                let response = try await transport.send(request)
                if response.statusCode >= 500 {
                    throw Retryable.server(response.statusCode)
                }
                return response
            } catch is CancellationError {
                throw CancellationError()
            } catch let retryable as Retryable {
                guard attempt < configuration.maxRetries else { throw retryable }
                attempt += 1
                try await clock.sleep(for: configuration.retryDelay)
            } catch let transportError as LLMTransportError {
                guard attempt < configuration.maxRetries else { throw transportError }
                attempt += 1
                try await clock.sleep(for: configuration.retryDelay)
            }
        }
    }

    private static func mapStatus(_ status: Int, model: String) throws {
        switch status {
        case 200 ..< 300:
            return
        case 401, 403:
            throw LLMError.unauthorized
        case 404:
            throw LLMError.invalidModel(model)
        case 408:
            throw LLMError.timedOut
        case 429:
            throw LLMError.rateLimited
        case 400, 422:
            throw LLMError.invalidRequest("invalid request")
        default:
            throw LLMError.provider("unexpected status \(status)")
        }
    }

    private static func map(_ error: Error) -> LLMError {
        if let llmError = error as? LLMError {
            return llmError
        }
        if let retryable = error as? Retryable {
            switch retryable {
            case let .server(status):
                return .server(status: status)
            }
        }
        if let transportError = error as? LLMTransportError {
            switch transportError {
            case .timedOut:
                return .timedOut
            case let .connection(message):
                return .provider(message)
            }
        }
        return .provider(String(describing: error))
    }
}
