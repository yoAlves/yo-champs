import Foundation

public struct ProviderProfile: Codable, Sendable, Equatable {
    public let id: String
    public let label: String
    public let kind: ProviderKind
    public let baseURL: URL
    public let model: String
    public let headers: [String: String]
    public let secretRef: String
    public let capabilities: Set<Capability>
    public let isDefault: Bool

    public init(
        id: String,
        label: String,
        kind: ProviderKind,
        baseURL: URL,
        model: String,
        headers: [String: String],
        secretRef: String,
        capabilities: Set<Capability>,
        isDefault: Bool
    ) {
        self.id = id
        self.label = label
        self.kind = kind
        self.baseURL = baseURL
        self.model = model
        self.headers = headers
        self.secretRef = secretRef
        self.capabilities = capabilities
        self.isDefault = isDefault
    }
}

/// Core names the compatibility protocol, not a vendor. The config layer maps
/// the on-disk wire value to this case without leaking vendor names into Core.
public enum ProviderKind: String, Codable, Sendable, CaseIterable {
    case compatible
}

public enum Capability: String, Codable, Sendable, CaseIterable {
    case streaming
    case reasoningEffort
    case tools
    case maxContext
}
