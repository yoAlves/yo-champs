import Foundation
import YoChampsCore
import YoChampsProviders

/// Real network boundary for `OpenAICompatibleProvider`. All protocol logic
/// stays in Providers; this adapter only performs the HTTP request and maps
/// platform errors to the transport contract.
public struct URLSessionLLMTransport: LLMHTTPTransport {
    private let session: URLSession

    /// Provider traffic uses an ephemeral session: no shared disk cache, cookies
    /// or credential reuse with other apps.
    public init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.urlCache = nil
            configuration.httpCookieStorage = nil
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            self.session = URLSession(configuration: configuration)
        }
    }

    public func send(_ request: LLMHTTPRequest) async throws -> LLMHTTPResponse {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = request.timeout / .seconds(1)
        urlRequest.httpBody = request.body
        for (name, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: name)
        }

        do {
            let (bytes, response) = try await session.bytes(for: urlRequest)
            guard let http = response as? HTTPURLResponse else {
                throw LLMTransportError.connection("invalid HTTP response")
            }
            let body = AsyncThrowingStream<UInt8, Error> { continuation in
                let producer = Task {
                    do {
                        for try await byte in bytes {
                            try Task.checkCancellation()
                            continuation.yield(byte)
                        }
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: Self.map(error))
                    }
                }
                continuation.onTermination = { _ in producer.cancel() }
            }
            return LLMHTTPResponse(statusCode: http.statusCode, body: body)
        } catch {
            throw Self.map(error)
        }
    }

    private static func map(_ error: Error) -> Error {
        guard let urlError = error as? URLError else { return error }
        switch urlError.code {
        case .timedOut:
            return LLMTransportError.timedOut
        case .cancelled:
            return CancellationError()
        default:
            return LLMTransportError.connection(urlError.localizedDescription)
        }
    }
}
