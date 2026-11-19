import Foundation
import Testing
import YoChampsCore
@testable import YoChampsMac
import YoChampsProviders

private struct UnexpectedStubCall: Error {}

/// `validatedURL()` is the only surface under test; any real use of these
/// doubles fails loudly instead of touching Keychain or the network.
private struct StubSecretStore: SecretStore {
    func secret(for ref: String) async throws -> String? {
        nil
    }

    func setSecret(_ value: String?, for ref: String) async throws {
        throw UnexpectedStubCall()
    }
}

private struct StubTransport: LLMHTTPTransport {
    func send(_ request: LLMHTTPRequest) async throws -> LLMHTTPResponse {
        throw UnexpectedStubCall()
    }
}

@MainActor
@Suite("SettingsViewModel")
struct SettingsViewModelTests {
    private func makeViewModel() -> SettingsViewModel {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("YoChampsSettingsTests-\(UUID().uuidString)")
        return SettingsViewModel(
            store: ProviderConfigFileStore(directory: directory),
            secrets: StubSecretStore(),
            transport: StubTransport(),
            packLoader: MascotPackLoader(supportDirectory: directory)
        )
    }

    private func waitUntil(
        _ condition: () -> Bool,
        timeout: TimeInterval = 5
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(condition(), "condition not met within \(timeout)s")
    }

    @Test("rejects http base URLs outside loopback")
    func rejectsRemoteHTTP() {
        let model = makeViewModel()
        model.baseURL = "http://example.com/v1"

        #expect {
            try model.validatedURL()
        } throws: { error in
            error as? ProviderConfigError == .insecureBaseURL(profileID: "personal", host: "example.com")
        }
    }

    @Test("accepts loopback http and remote https base URLs")
    func acceptsSecureURLs() throws {
        let model = makeViewModel()
        for baseURL in ["http://localhost:11434/v1", "https://example.com/v1"] {
            model.baseURL = baseURL
            #expect(try model.validatedURL().absoluteString == baseURL)
        }
    }

    @Test("keeps the invalid base URL error for non-http schemes")
    func rejectsNonHTTPScheme() {
        let model = makeViewModel()
        model.baseURL = "ftp://example.com/v1"

        #expect {
            try model.validatedURL()
        } throws: { error in
            error as? SettingsError == .invalidBaseURL
        }
    }

    @Test("test connection rejects an insecure URL before reading the key")
    func connectionRejectsBeforeKeychain() async throws {
        let model = makeViewModel()
        model.baseURL = "http://example.com/v1"
        model.model = "test-model"

        model.testConnection()
        try await waitUntil { model.message != nil }

        #expect(model.message?.isError == true)
        #expect(model.message?.text.localizedCaseInsensitiveContains("https") == true)
    }
}
