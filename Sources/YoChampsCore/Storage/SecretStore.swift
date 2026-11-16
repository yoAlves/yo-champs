import Foundation

/// Keychain-backed secret access. References are opaque strings; the store
/// implementation owns the service/account mapping. Values are never logged.
public protocol SecretStore: Sendable {
    func secret(for ref: String) async throws -> String?
    func setSecret(_ value: String?, for ref: String) async throws
}
