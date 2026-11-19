import Foundation
import OSLog
import YoChampsCore
import YoChampsProviders

public enum SettingsError: Error, Sendable, Equatable, CustomStringConvertible {
    case invalidBaseURL
    case missingModel
    case missingKey
    case invalidHeader(Int)
    case invalidModelSelection(ModelSelectionError)

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
        case let .invalidModelSelection(error):
            error.description
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
    @Published var mascotStatus: String?

    private let store: ProviderConfigFileStore
    private let secrets: any SecretStore
    private let transport: any LLMHTTPTransport
    private let packLoader: MascotPackLoader
    var onSaved: () -> Void
    private let logger = Logger(subsystem: "com.yurioliveira.yochamps", category: "settings")
    private var profileID: String?
    private var work: Task<Void, Never>?

    init(
        store: ProviderConfigFileStore,
        secrets: any SecretStore,
        transport: any LLMHTTPTransport,
        packLoader: MascotPackLoader = MascotPackLoader(),
        onSaved: @escaping () -> Void = {}
    ) {
        self.store = store
        self.secrets = secrets
        self.transport = transport
        self.packLoader = packLoader
        self.onSaved = onSaved
    }

    func load() async {
        loadMascotStatus()
        do {
            guard let registry = try await store.load() else {
                isOnboarding = true
                return
            }
            let profile = registry.defaultProfile
            profileID = profile.id
            baseURL = profile.baseURL.absoluteString
            model = ModelSelection(model: profile.model, effort: profile.reasoningEffort).displayString
            secretRef = profile.secretRef
            headers = profile.headers.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
            hasStoredKey = await ((try? secrets.secret(for: profile.secretRef))?.isEmpty == false)
            isOnboarding = false
        } catch {
            message = .error(Self.display(error))
        }
    }

    /// Reports only why a fallback happened; loading itself stays silent when
    /// a single local pack (or none) is in use.
    private func loadMascotStatus() {
        do {
            switch try packLoader.load() {
            case .selected:
                mascotStatus = nil
            case let .fallback(_, detail):
                mascotStatus = detail.isEmpty ? nil : detail
            }
        } catch {
            logger.error("mascot pack load failed: \(String(describing: error), privacy: .private)")
            mascotStatus = "The default mascot pack could not be loaded."
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
            let capabilities = resolvedCapabilities(base: base)
            let selection = try validatedSelection()
            let profile = try ProviderProfile(
                id: id,
                label: base?.label ?? "Personal",
                kind: .compatible,
                baseURL: validatedURL(),
                model: selection.model,
                headers: parsedHeaders(),
                secretRef: reference,
                capabilities: capabilities,
                reasoningEffort: selection.effort,
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
            onSaved()
        } catch is CancellationError {
            message = .info("Cancelled")
        } catch {
            message = .error(Self.display(error))
        }
    }

    /// A new profile starts with streaming only; an existing profile keeps its
    /// declared capabilities.
    private func resolvedCapabilities(base: ProviderProfile?) -> Set<Capability> {
        guard let base, !base.capabilities.isEmpty else {
            return [.streaming]
        }
        return base.capabilities
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
            // Validate the transport before touching the Keychain or any
            // header: a remote http URL must never carry a bearer token.
            let baseURL = try validatedURL()
            let selection = try validatedSelection()
            let reference = secretRef.isEmpty ? "keychain:provider/\(profileID ?? "personal")" : secretRef
            let typedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = try await typedKey.isEmpty ? storedKeyOrThrow(for: reference) : typedKey
            var requestHeaders = try parsedHeaders()
            requestHeaders = requestHeaders.filter { $0.key.lowercased() != "authorization" }
            requestHeaders["Authorization"] = "Bearer \(key)"
            let configuration = try OpenAICompatibleProvider.Configuration(
                baseURL: baseURL,
                maxRetries: 0,
                timeout: .seconds(10)
            )
            let provider = OpenAICompatibleProvider(
                configuration: configuration,
                transport: transport
            )
            let request = try LLMRequest(
                model: selection.model,
                messages: [.init(role: .user, content: "Reply with OK")],
                maxTokens: 256,
                reasoningEffort: selection.effort,
                headers: requestHeaders
            )
            var answer = ""
            for try await event in provider.stream(request) {
                try Task.checkCancellation()
                if case let .textDelta(delta) = event {
                    answer += delta
                }
            }
            // Keep the typed key visible until Save or close: clearing it here
            // makes it look lost and silently discards a newly entered key.
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
        apiKey = ""
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

    func validatedURL() throws -> URL {
        guard let url = URL(string: baseURL.trimmingCharacters(in: .whitespaces)),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host, !host.isEmpty
        else {
            throw SettingsError.invalidBaseURL
        }
        try ProviderTransportPolicy.requireSecure(url, profileID: profileID ?? "personal")
        return url
    }

    func validatedSelection() throws -> ModelSelection {
        do {
            return try ModelSelection(parsing: model)
        } catch let error as ModelSelectionError {
            throw SettingsError.invalidModelSelection(error)
        }
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
