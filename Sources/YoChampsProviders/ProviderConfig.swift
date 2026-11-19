import Foundation
import YoChampsCore

public enum ProviderConfigError: Error, Sendable, Equatable, CustomStringConvertible {
    case unsupportedSchemaVersion(Int)
    case unsupportedKind(String)
    case duplicateProfileID(String)
    case unknownDefaultProfile(String)
    case missingDefaultProfile
    case multipleDefaultProfiles
    case invalidSecretRef(String)
    case credentialHeader(String)
    case emptyField(profileID: String, field: String)
    case invalidBaseURL(profileID: String)
    case insecureBaseURL(profileID: String, host: String)
    case malformedConfig(String)

    public var description: String {
        switch self {
        case let .unsupportedSchemaVersion(version):
            "unsupported config schemaVersion \(version); expected 1"
        case let .unsupportedKind(kind):
            "unsupported provider kind '\(kind)'"
        case let .duplicateProfileID(id):
            "duplicate provider profile id '\(id)'"
        case let .unknownDefaultProfile(id):
            "defaultProfileID '\(id)' is not a registered profile"
        case .missingDefaultProfile:
            "no default profile: set defaultProfileID or mark exactly one profile isDefault"
        case .multipleDefaultProfiles:
            "more than one profile is marked isDefault; set defaultProfileID"
        case let .invalidSecretRef(id):
            "profile '\(id)' needs a keychain reference of the form keychain:<service>/<ref>"
        case let .credentialHeader(name):
            "header '\(name)' looks like a credential; store the key in the Keychain"
        case let .emptyField(profileID, field):
            "profile '\(profileID)' has an empty \(field)"
        case let .invalidBaseURL(profileID):
            "profile '\(profileID)' needs an absolute http(s) baseURL"
        case let .insecureBaseURL(profileID, host):
            "profile '\(profileID)' needs https for '\(host)'; http is limited to loopback hosts"
        case let .malformedConfig(path):
            "config.json is malformed at \(path)"
        }
    }
}

/// The single transport rule for every base URL: https anywhere, http only
/// for a provider running on this machine. The config loader and the Settings
/// "Test connection" path both go through here, so a key-bearing request can
/// never be sent in cleartext to a remote host.
public enum ProviderTransportPolicy {
    public static func isLoopback(host: String) -> Bool {
        var normalized = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.hasPrefix("["), normalized.hasSuffix("]") {
            normalized = String(normalized.dropFirst().dropLast())
        }
        return normalized == "localhost" || normalized == "127.0.0.1" || normalized == "::1"
    }

    public static func requireSecure(_ url: URL, profileID: String) throws {
        guard url.scheme?.lowercased() == "http" else { return }
        let host = url.host ?? ""
        guard isLoopback(host: host) else {
            throw ProviderConfigError.insecureBaseURL(profileID: profileID, host: host)
        }
    }
}

/// One set of field-level invariants shared by the decoder, the registry
/// constructor and the encoder, so no write path can persist a profile the
/// loader would reject (or a secret hidden in a header).
private enum ProviderProfileValidation {
    static func validate(_ profile: ProviderProfile) throws {
        for (field, value) in [
            ("id", profile.id),
            ("label", profile.label),
            ("model", profile.model),
            ("secretRef", profile.secretRef),
        ] where value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ProviderConfigError.emptyField(profileID: profile.id, field: field)
        }
        if profile.reasoningEffort?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            throw ProviderConfigError.emptyField(profileID: profile.id, field: "reasoningEffort")
        }
        guard let scheme = profile.baseURL.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              profile.baseURL.host?.isEmpty == false
        else {
            throw ProviderConfigError.invalidBaseURL(profileID: profile.id)
        }
        try ProviderTransportPolicy.requireSecure(profile.baseURL, profileID: profile.id)
        try validateSecretRef(profile.secretRef, profileID: profile.id)
        for (name, value) in profile.headers {
            let normalizedValue = value.trimmingCharacters(in: .whitespaces).lowercased()
            guard !isCredentialHeader(name),
                  !normalizedValue.contains("bearer "),
                  !normalizedValue.contains("basic "),
                  !normalizedValue.hasPrefix("sk-")
            else {
                throw ProviderConfigError.credentialHeader(name)
            }
        }
    }

    private static func validateSecretRef(_ ref: String, profileID: String) throws {
        guard ref.hasPrefix("keychain:") else {
            throw ProviderConfigError.invalidSecretRef(profileID)
        }
        let remainder = ref.dropFirst("keychain:".count)
        guard let slash = remainder.firstIndex(of: "/"), slash > remainder.startIndex,
              !remainder[remainder.index(after: slash)...].isEmpty
        else {
            throw ProviderConfigError.invalidSecretRef(profileID)
        }
    }

    private static func isCredentialHeader(_ name: String) -> Bool {
        let normalized = name.lowercased().filter(\.isLetter)
        let words = ["authorization", "authentication", "apikey", "token",
                     "secret", "cookie", "password", "credential"]
        return words.contains { normalized.contains($0) }
    }
}

private struct ProviderConfigFile: Decodable {
    let schemaVersion: Int
    let defaultProfileID: String?
    let profiles: [ProviderProfileWire]
}

private struct ProviderProfileWire: Decodable {
    let id: String
    let label: String
    let kind: String
    let baseURL: URL
    let model: String
    let headers: [String: String]?
    let secretRef: String
    let capabilities: [Capability]?
    let reasoningEffort: String?
    let isDefault: Bool?
}

private struct ProviderConfigOutput: Encodable {
    let schemaVersion: Int
    let defaultProfileID: String
    let profiles: [ProviderProfileOutput]
}

private struct ProviderProfileOutput: Encodable {
    let id: String
    let label: String
    let kind: String
    let baseURL: URL
    let model: String
    let headers: [String: String]
    let secretRef: String
    let capabilities: [Capability]
    let reasoningEffort: String?
    let isDefault: Bool

    init(profile: ProviderProfile, defaultID: String) {
        id = profile.id
        label = profile.label
        kind = ProviderConfigDecoder.wireKind
        baseURL = profile.baseURL
        model = profile.model
        headers = profile.headers
        secretRef = profile.secretRef
        capabilities = profile.capabilities.sorted { $0.rawValue < $1.rawValue }
        reasoningEffort = profile.reasoningEffort
        isDefault = profile.id == defaultID
    }
}

/// The resolved, validated set of profiles. `defaultProfileID` in the config
/// file is the single source of truth for the default.
public struct ProviderRegistry: Sendable, Equatable {
    public let profiles: [ProviderProfile]
    public let defaultProfile: ProviderProfile

    init(profiles: [ProviderProfile], defaultProfile: ProviderProfile) {
        self.profiles = profiles
        self.defaultProfile = defaultProfile
    }

    /// Validates ids and normalizes `isDefault` so lookups and the resolved
    /// default can never disagree.
    public init(profiles: [ProviderProfile], defaultProfileID: String) throws {
        var seen = Set<String>()
        for profile in profiles {
            try ProviderProfileValidation.validate(profile)
            guard seen.insert(profile.id).inserted else {
                throw ProviderConfigError.duplicateProfileID(profile.id)
            }
        }
        guard let storedDefault = profiles.first(where: { $0.id == defaultProfileID }) else {
            throw ProviderConfigError.unknownDefaultProfile(defaultProfileID)
        }
        let normalized = profiles.map { profile in
            ProviderProfile(
                id: profile.id,
                label: profile.label,
                kind: profile.kind,
                baseURL: profile.baseURL,
                model: profile.model,
                headers: profile.headers,
                secretRef: profile.secretRef,
                capabilities: profile.capabilities,
                reasoningEffort: profile.reasoningEffort,
                isDefault: profile.id == defaultProfileID
            )
        }
        guard let defaultProfile = normalized.first(where: { $0.id == storedDefault.id }) else {
            throw ProviderConfigError.unknownDefaultProfile(defaultProfileID)
        }
        self.init(profiles: normalized, defaultProfile: defaultProfile)
    }

    public func profile(id: String) -> ProviderProfile? {
        profiles.first { $0.id == id }
    }
}

public enum ProviderConfigDecoder {
    public static let schemaVersion = 1
    fileprivate static let wireKind = "openai-compatible"

    public static func decode(_ data: Data) throws -> ProviderRegistry {
        let file: ProviderConfigFile
        do {
            file = try JSONDecoder().decode(ProviderConfigFile.self, from: data)
        } catch {
            throw ProviderConfigError.malformedConfig(path(for: error))
        }
        guard file.schemaVersion == schemaVersion else {
            throw ProviderConfigError.unsupportedSchemaVersion(file.schemaVersion)
        }

        var profiles: [ProviderProfile] = []
        var seen = Set<String>()
        var flaggedDefault: ProviderProfile?
        for wire in file.profiles {
            let profile = try map(wire)
            guard seen.insert(profile.id).inserted else {
                throw ProviderConfigError.duplicateProfileID(profile.id)
            }
            if file.defaultProfileID == nil, profile.isDefault {
                guard flaggedDefault == nil else {
                    throw ProviderConfigError.multipleDefaultProfiles
                }
                flaggedDefault = profile
            }
            profiles.append(profile)
        }
        return try resolve(file: file, profiles: profiles, flaggedDefault: flaggedDefault)
    }

    private static func resolve(
        file: ProviderConfigFile,
        profiles: [ProviderProfile],
        flaggedDefault: ProviderProfile?
    ) throws -> ProviderRegistry {
        let defaultID: String
        if let configuredID = file.defaultProfileID {
            guard profiles.contains(where: { $0.id == configuredID }) else {
                throw ProviderConfigError.unknownDefaultProfile(configuredID)
            }
            defaultID = configuredID
        } else if let flaggedDefault {
            defaultID = flaggedDefault.id
        } else {
            throw ProviderConfigError.missingDefaultProfile
        }

        let resolved = profiles.map { profile in
            ProviderProfile(
                id: profile.id,
                label: profile.label,
                kind: profile.kind,
                baseURL: profile.baseURL,
                model: profile.model,
                headers: profile.headers,
                secretRef: profile.secretRef,
                capabilities: profile.capabilities,
                reasoningEffort: profile.reasoningEffort,
                isDefault: profile.id == defaultID
            )
        }
        guard let defaultProfile = resolved.first(where: { $0.id == defaultID }) else {
            throw ProviderConfigError.unknownDefaultProfile(defaultID)
        }
        return ProviderRegistry(profiles: resolved, defaultProfile: defaultProfile)
    }

    private static func map(_ wire: ProviderProfileWire) throws -> ProviderProfile {
        guard wire.kind == wireKind else {
            throw ProviderConfigError.unsupportedKind(wire.kind)
        }
        let profile = ProviderProfile(
            id: wire.id,
            label: wire.label,
            kind: .compatible,
            baseURL: wire.baseURL,
            model: wire.model,
            headers: wire.headers ?? [:],
            secretRef: wire.secretRef,
            capabilities: Set(wire.capabilities ?? []),
            reasoningEffort: wire.reasoningEffort,
            isDefault: wire.isDefault ?? false
        )
        try ProviderProfileValidation.validate(profile)
        return profile
    }
}

/// Serializes the validated profile set back to the versioned wire format.
/// Only references are written: secrets stay in the Keychain.
public enum ProviderConfigEncoder {
    public static func encode(profiles: [ProviderProfile], defaultProfileID: String) throws -> Data {
        let registry = try ProviderRegistry(profiles: profiles, defaultProfileID: defaultProfileID)
        let output = ProviderConfigOutput(
            schemaVersion: ProviderConfigDecoder.schemaVersion,
            defaultProfileID: defaultProfileID,
            profiles: registry.profiles.map { ProviderProfileOutput(profile: $0, defaultID: defaultProfileID) }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(output)
    }
}

extension ProviderConfigDecoder {
    private static func path(for error: Error) -> String {
        guard let decodingError = error as? DecodingError else { return "config.json" }
        let components: [String]
        switch decodingError {
        case let .keyNotFound(_, context),
             let .typeMismatch(_, context),
             let .valueNotFound(_, context):
            components = codingPath(context)
        case let .dataCorrupted(context):
            components = codingPath(context)
        @unknown default:
            return "config.json"
        }
        return components.isEmpty ? "config.json" : "config.json.\(components.joined(separator: "."))"
    }

    private static func codingPath(_ context: DecodingError.Context) -> [String] {
        context.codingPath.map { key in
            if let index = key.intValue {
                return "[\(index)]"
            }
            return key.stringValue
        }
    }
}
