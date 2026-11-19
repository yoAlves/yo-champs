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
            let redirectGuard = RedirectGuard(originalURL: request.url)
            let (bytes, response) = try await session.bytes(
                for: urlRequest,
                delegate: redirectGuard
            )
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

/// Redirects may only stay on the configured provider origin: scheme, host and
/// port must match the original request. The request carries the
/// Keychain-backed key, so a cross-origin redirect must not receive it.
struct RedirectPolicy: Sendable, Equatable {
    private let scheme: String
    private let host: String
    private let port: Int?

    init(url: URL) {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let scheme = components?.scheme?.lowercased() ?? ""
        self.scheme = scheme
        host = components?.host?.lowercased() ?? ""
        port = Self.effectivePort(scheme: scheme, port: components?.port)
    }

    func allows(_ url: URL) -> Bool {
        guard !scheme.isEmpty,
              !host.isEmpty,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let newScheme = components.scheme?.lowercased(),
              let newHost = components.host?.lowercased()
        else {
            return false
        }
        return newScheme == scheme
            && newHost == host
            && Self.effectivePort(scheme: newScheme, port: components.port) == port
    }

    private static func effectivePort(scheme: String, port: Int?) -> Int? {
        if let port {
            return port
        }
        switch scheme {
        case "http": return 80
        case "https": return 443
        default: return nil
        }
    }
}

private final class RedirectGuard: NSObject, URLSessionTaskDelegate {
    private let policy: RedirectPolicy

    init(originalURL: URL) {
        policy = RedirectPolicy(url: originalURL)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        guard let url = request.url, policy.allows(url) else {
            completionHandler(nil)
            return
        }
        completionHandler(request)
    }
}
