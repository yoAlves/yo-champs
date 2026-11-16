import Foundation
import YoChampsCore
import YoChampsProviders

public enum SettingsError: Error, Sendable, Equatable, CustomStringConvertible {
    case invalidBaseURL
    case missingModel
    case missingKey
    case invalidHeader(Int)

    public var description: String {
        switch self {
        case .invalidBaseURL:
            "Enter an absolute http(s) base URL, ending in /v1"
        case .missingModel:
            "Enter a model id for this profile"
        case .missingKey:
            "Add an API key — it is stored in the Keychain, not in config.json"
        case let .invalidHeader(line):
            "Header on line \(line) must use Name: value format"
        }
    }
}

public enum SettingsMessage: Equatable {
    case info(String)
    case error(String)

    var text: String {
        switch self {
        case let .info(text), let .error(text):
            text
        }
    }

    var isError: Bool {
        if case .error = self {
            return true
        }
        return false
    }
}

/// Main-actor state for Settings and onboarding. The key is entered in a
/// SecureField, written only to Keychain, then dropped from memory; config
/// holds only the `secretRef`.
@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var baseURL = ""
    @Published var model = ""
    @Published var secretRef = ""
    @Published var apiKey = ""
    @Published var headers = ""
    @Published var hasStoredKey = false
    @Published var isOnboarding = false
    @Published var isWorking = false
    @Published var message: SettingsMessage?

    private let store: ProviderConfigFileStore
    private let secrets: any SecretStore
    private let transport: any LLMHTTPTransport
    private var profileID: String?
    private var work: Task<Void, Never>?

    init(
        store: ProviderConfigFileStore,
        secrets: any SecretStore,
        transport: any LLMHTTPTransport
    ) {
        self.store = store
        self.secrets = secrets
        self.transport = transport
    }

    func load() async {
        do {
            guard let registry = try await store.load() else {
                isOnboarding = true
                return
            }
            let profile = registry.defaultProfile
            profileID = profile.id
            baseURL = profile.baseURL.absoluteString
            model = profile.model
            secretRef = profile.secretRef
            headers = profile.headers.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
            hasStoredKey = await ((try? secrets.secret(for: profile.secretRef))?.isEmpty == false)
            isOnboarding = false
        } catch {
            message = .error(Self.display(error))
        }
    }

    func save() {
        work?.cancel()
        work = Task { [weak self] in
            await self?.performSave()
        }
    }

    private func performSave() async {
        message = nil
        isWorking = true
        defer { isWorking = false }
        do {
            let id = profileID ?? "personal"
            let reference = secretRef.isEmpty ? "keychain:provider/\(id)" : secretRef
            let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            let existing = try await store.load()

            // Validate everything before any side effect (especially Keychain).
            let base = existing?.profile(id: id)
            let capabilities: Set<Capability> = if let base, !base.capabilities.isEmpty {
                base.capabilities
            } else {
                [.streaming]
            }
            let profile = try ProviderProfile(
                id: id,
                label: base?.label ?? "Personal",
                kind: .compatible,
                baseURL: validatedURL(),
                model: validatedModel(),
                headers: parsedHeaders(),
                secretRef: reference,
                capabilities: capabilities,
                isDefault: true
            )
            var profiles = existing?.profiles ?? []
            if let index = profiles.firstIndex(where: { $0.id == id }) {
                profiles[index] = profile
            } else {
                profiles.append(profile)
            }
            let registry = try ProviderRegistry(profiles: profiles, defaultProfileID: id)

            if !key.isEmpty {
                try await secrets.setSecret(key, for: reference)
            } else if try await !storedKey(for: reference) {
                throw SettingsError.missingKey
            }
            try await store.save(registry)
            secretRef = reference
            profileID = id
            hasStoredKey = true
            apiKey = ""
            isOnboarding = false
            message = .info("Profile saved")
        } catch is CancellationError {
            message = .info("Cancelled")
        } catch {
            message = .error(Self.display(error))
        }
    }

    func testConnection() {
        work?.cancel()
        work = Task { [weak self] in
            await self?.performTest()
        }
    }

    private func performTest() async {
        message = nil
        isWorking = true
        defer { isWorking = false }
        do {
            let reference = secretRef.isEmpty ? "keychain:provider/\(profileID ?? "personal")" : secretRef
            let typedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = try await typedKey.isEmpty ? storedKeyOrThrow(for: reference) : typedKey
            var requestHeaders = try parsedHeaders()
            requestHeaders = requestHeaders.filter { $0.key.lowercased() != "authorization" }
            requestHeaders["Authorization"] = "Bearer \(key)"
            let configuration = try OpenAICompatibleProvider.Configuration(
                baseURL: validatedURL(),
                maxRetries: 0,
                timeout: .seconds(10)
            )
            let provider = OpenAICompatibleProvider(
                configuration: configuration,
                transport: transport
            )
            let request = try LLMRequest(
                model: validatedModel(),
                messages: [.init(role: .user, content: "Reply with OK")],
                maxTokens: 1,
                headers: requestHeaders
            )
            var answer = ""
            for try await event in provider.stream(request) {
                try Task.checkCancellation()
                if case let .textDelta(delta) = event {
                    answer += delta
                }
            }
            apiKey = ""
            message = .info(answer.isEmpty ? "Connected but the provider sent no text" : "Connection OK")
        } catch is CancellationError {
            message = .info("Cancelled")
        } catch {
            message = .error(Self.display(error))
        }
    }

    /// Called when the panel closes so an in-flight test cannot write into a
    /// model the user can no longer see.
    func stop() {
        work?.cancel()
        work = nil
        isWorking = false
    }

    private func storedKey(for reference: String) async throws -> Bool {
        guard let value = try await secrets.secret(for: reference), !value.isEmpty else {
            return false
        }
        return true
    }

    private func storedKeyOrThrow(for reference: String) async throws -> String {
        guard let value = try await secrets.secret(for: reference), !value.isEmpty else {
            throw SettingsError.missingKey
        }
        return value
    }

    private func validatedURL() throws -> URL {
        guard let url = URL(string: baseURL.trimmingCharacters(in: .whitespaces)),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host, !host.isEmpty
        else {
            throw SettingsError.invalidBaseURL
        }
        return url
    }

    private func validatedModel() throws -> String {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SettingsError.missingModel }
        return trimmed
    }

    private func parsedHeaders() throws -> [String: String] {
        var result: [String: String] = [:]
        let lines = headers.split(whereSeparator: \.isNewline)
        for (offset, line) in lines.enumerated() {
            let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else {
                throw SettingsError.invalidHeader(offset + 1)
            }
            let name = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty, !value.isEmpty else {
                throw SettingsError.invalidHeader(offset + 1)
            }
            result[name] = value
        }
        return result
    }

    private static func display(_ error: Error) -> String {
        if error is CancellationError {
            return "Cancelled"
        }
        if let settingsError = error as? SettingsError {
            return settingsError.description
        }
        if let llmError = error as? LLMError {
            return llmError.description
        }
        if let configError = error as? ProviderConfigError {
            return configError.description
        }
        if error is KeychainError {
            return String(describing: error)
        }
        return error.localizedDescription
    }
}
