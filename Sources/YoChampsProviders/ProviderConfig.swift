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
        case let .malformedConfig(path):
            "config.json is malformed at \(path)"
        }
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
    let isDefault: Bool?
}

/// The resolved, validated set of profiles. `defaultProfileID` in the config
/// file is the single source of truth for the default.
public struct ProviderRegistry: Sendable, Equatable {
    public let profiles: [ProviderProfile]
    public let defaultProfile: ProviderProfile

    public func profile(id: String) -> ProviderProfile? {
        profiles.first { $0.id == id }
    }
}

public enum ProviderConfigDecoder {
    public static let schemaVersion = 1
    private static let wireKind = "openai-compatible"
    private static let referencePrefix = "keychain:"
    private static let credentialWords = [
        "authorization", "authentication", "apikey", "token",
        "secret", "cookie", "password", "credential",
    ]

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
        for (field, value) in [
            ("id", wire.id),
            ("label", wire.label),
            ("model", wire.model),
            ("secretRef", wire.secretRef),
        ] where value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ProviderConfigError.emptyField(profileID: wire.id, field: field)
        }
        guard let scheme = wire.baseURL.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = wire.baseURL.host, !host.isEmpty
        else {
            throw ProviderConfigError.invalidBaseURL(profileID: wire.id)
        }
        try validateSecretRef(wire.secretRef, profileID: wire.id)

        let headers = wire.headers ?? [:]
        for (name, value) in headers {
            let normalizedValue = value.trimmingCharacters(in: .whitespaces).lowercased()
            guard !isCredentialHeader(name),
                  !normalizedValue.contains("bearer "),
                  !normalizedValue.contains("basic "),
                  !normalizedValue.hasPrefix("sk-")
            else {
                throw ProviderConfigError.credentialHeader(name)
            }
        }
        return ProviderProfile(
            id: wire.id,
            label: wire.label,
            kind: .compatible,
            baseURL: wire.baseURL,
            model: wire.model,
            headers: headers,
            secretRef: wire.secretRef,
            capabilities: Set(wire.capabilities ?? []),
            isDefault: wire.isDefault ?? false
        )
    }

    private static func validateSecretRef(_ ref: String, profileID: String) throws {
        guard ref.hasPrefix(referencePrefix) else {
            throw ProviderConfigError.invalidSecretRef(profileID)
        }
        let remainder = ref.dropFirst(Self.referencePrefix.count)
        guard let slash = remainder.firstIndex(of: "/"), slash > remainder.startIndex,
              !remainder[remainder.index(after: slash)...].isEmpty
        else {
            throw ProviderConfigError.invalidSecretRef(profileID)
        }
    }

    private static func isCredentialHeader(_ name: String) -> Bool {
        let normalized = name.lowercased().filter(\.isLetter)
        return credentialWords.contains { normalized.contains($0) }
    }

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
