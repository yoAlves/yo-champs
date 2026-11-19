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

private actor InMemorySecretStore: SecretStore {
    private var values: [String: String] = [:]
    private(set) var setCalls = 0

    func secret(for ref: String) async throws -> String? {
        values[ref]
    }

    func setSecret(_ value: String?, for ref: String) async throws {
        setCalls += 1
        values[ref] = value
    }
}

private actor RecordingTransport: LLMHTTPTransport {
    private(set) var requests: [LLMHTTPRequest] = []

    func send(_ request: LLMHTTPRequest) async throws -> LLMHTTPResponse {
        requests.append(request)
        let sse = "data: {\"choices\":[{\"delta\":{\"content\":\"OK\"}}]}\n\ndata: [DONE]\n\n"
        let body = AsyncThrowingStream<UInt8, Error> { continuation in
            for byte in Array(sse.utf8) {
                continuation.yield(byte)
            }
            continuation.finish()
        }
        return LLMHTTPResponse(statusCode: 200, body: body)
    }
}

@MainActor
@Suite("SettingsViewModel")
struct SettingsViewModelTests {
    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("YoChampsSettingsTests-\(UUID().uuidString)")
    }

    private func makeViewModel(
        directory: URL? = nil,
        secrets: any SecretStore = StubSecretStore(),
        transport: any LLMHTTPTransport = StubTransport()
    ) -> SettingsViewModel {
        let directory = directory ?? temporaryDirectory()
        return SettingsViewModel(
            store: ProviderConfigFileStore(directory: directory),
            secrets: secrets,
            transport: transport,
            packLoader: MascotPackLoader(supportDirectory: directory)
        )
    }

    private func profile(model: String = "test-model", effort: String? = nil) -> ProviderProfile {
        ProviderProfile(
            id: "personal",
            label: "Personal",
            kind: .compatible,
            baseURL: URL(string: "https://example.test/v1")!,
            model: model,
            headers: [:],
            secretRef: "keychain:provider/personal",
            capabilities: [.streaming],
            reasoningEffort: effort,
            isDefault: true
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

    @Test("loads a saved effort into the model field")
    func loadsSavedEffort() async throws {
        let directory = temporaryDirectory()
        let store = ProviderConfigFileStore(directory: directory)
        try await store.save(
            ProviderRegistry(
                profiles: [profile(model: "m", effort: "low")],
                defaultProfileID: "personal"
            )
        )
        let viewModel = makeViewModel(directory: directory)

        await viewModel.load()

        #expect(viewModel.model == "m#low")
    }

    @Test("saves model and effort separately")
    func savesModelAndEffort() async throws {
        let directory = temporaryDirectory()
        let secrets = InMemorySecretStore()
        let viewModel = makeViewModel(directory: directory, secrets: secrets)
        viewModel.baseURL = "https://example.test/v1"
        viewModel.model = "m#low"
        viewModel.apiKey = "test-key"

        viewModel.save()
        try await waitUntil { viewModel.message != nil }

        #expect(viewModel.message?.isError == false)
        let reloaded = try await ProviderConfigFileStore(directory: directory).load()
        let registry = try #require(reloaded)
        #expect(registry.defaultProfile.model == "m")
        #expect(registry.defaultProfile.reasoningEffort == "low")
    }

    @Test("rejects an empty effort before saving")
    func rejectsEmptyEffort() async throws {
        let directory = temporaryDirectory()
        let secrets = InMemorySecretStore()
        let viewModel = makeViewModel(directory: directory, secrets: secrets)
        viewModel.baseURL = "https://example.test/v1"
        viewModel.model = "m#"

        viewModel.save()
        try await waitUntil { viewModel.message != nil }

        #expect(viewModel.message?.isError == true)
        #expect(viewModel.message?.text.localizedCaseInsensitiveContains("#") == true)
        let stored = try await ProviderConfigFileStore(directory: directory).load()
        #expect(stored == nil)
        let setCalls = await secrets.setCalls
        #expect(setCalls == 0)
    }

    @Test("test connection sends the selected effort")
    func connectionSendsEffort() async throws {
        let transport = RecordingTransport()
        let viewModel = makeViewModel(secrets: InMemorySecretStore(), transport: transport)
        viewModel.baseURL = "https://example.test/v1"
        viewModel.model = "m#low"
        viewModel.apiKey = "test-key"

        viewModel.testConnection()
        try await waitUntil { viewModel.message != nil }

        #expect(viewModel.message?.isError == false)
        let requests = await transport.requests
        #expect(requests.count == 1)
        let object = try JSONSerialization.jsonObject(with: requests[0].body) as? [String: Any]
        #expect(object?["model"] as? String == "m")
        #expect(object?["reasoning_effort"] as? String == "low")
    }
}
