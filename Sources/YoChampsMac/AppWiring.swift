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

/// Adds the Keychain-backed key at request time. The engine and the provider
/// never hold the secret; a missing key maps to the actionable domain error.
public struct KeychainAuthTransport: LLMHTTPTransport {
    private let secrets: any SecretStore
    private let secretRef: String
    private let base: any LLMHTTPTransport

    public init(
        secrets: any SecretStore,
        secretRef: String,
        base: any LLMHTTPTransport
    ) {
        self.secrets = secrets
        self.secretRef = secretRef
        self.base = base
    }

    public func send(_ request: LLMHTTPRequest) async throws -> LLMHTTPResponse {
        guard let key = try await secrets.secret(for: secretRef), !key.isEmpty else {
            throw LLMError.unauthorized
        }
        var headers = request.headers
        headers["Authorization"] = "Bearer \(key)"
        let authenticated = LLMHTTPRequest(
            url: request.url,
            headers: headers,
            body: request.body,
            timeout: request.timeout
        )
        return try await base.send(authenticated)
    }
}
