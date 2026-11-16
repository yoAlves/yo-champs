import Foundation
import YoChampsCore
import YoChampsNetwork
import YoChampsProviders

public enum AppPaths {
    public static var supportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("YoChamps", isDirectory: true)
    }
}

/// Used only when no profile exists: the user gets an actionable error instead
/// of a silent mock answer that looks like a real provider reply.
public struct UnconfiguredProvider: LLMProvider {
    public init() {}

    public func stream(_ request: LLMRequest) -> AsyncThrowingStream<LLMEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: LLMError.invalidRequest(
                "No provider configured — open Settings to add one"
            ))
        }
    }
}

/// Adds profile headers and the Keychain-backed key at request time. The
/// engine and provider never hold the secret, and a missing key maps to the
/// actionable domain error.
public struct KeychainAuthTransport: LLMHTTPTransport {
    private let secrets: any SecretStore
    private let secretRef: String
    private let extraHeaders: [String: String]
    private let base: any LLMHTTPTransport
    private let conversationID: String

    public init(
        secrets: any SecretStore,
        secretRef: String,
        extraHeaders: [String: String] = [:],
        base: any LLMHTTPTransport
    ) {
        self.secrets = secrets
        self.secretRef = secretRef
        self.extraHeaders = extraHeaders
        self.base = base
        conversationID = UUID().uuidString
    }

    public func send(_ request: LLMHTTPRequest) async throws -> LLMHTTPResponse {
        guard let key = try await secrets.secret(for: secretRef), !key.isEmpty else {
            throw LLMError.unauthorized
        }
        var headers = request.headers
        for (name, value) in extraHeaders {
            headers[name] = Self.expand(value, conversationID: conversationID)
        }
        headers["Authorization"] = "Bearer \(key)"
        let authenticated = LLMHTTPRequest(
            url: request.url,
            headers: headers,
            body: request.body,
            timeout: request.timeout
        )
        return try await base.send(authenticated)
    }

    private static func expand(_ value: String, conversationID: String) -> String {
        value
            .replacingOccurrences(of: "{{conversationId}}", with: conversationID)
            .replacingOccurrences(of: "{{appVersion}}", with: "0.0.0")
            .replacingOccurrences(of: "{{userAgent}}", with: "YoChamps/0.0.0")
    }
}
