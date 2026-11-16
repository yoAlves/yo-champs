import Foundation
import Security
import YoChampsCore

public enum KeychainError: Error, Sendable, Equatable, CustomStringConvertible {
    case operation(OSStatus)
    case invalidItem

    public var description: String {
        switch self {
        case let .operation(status):
            switch status {
            case errSecAuthFailed:
                "Keychain access was denied by authentication"
            case errSecUserCanceled:
                "Keychain access was cancelled"
            case errSecInteractionNotAllowed:
                "Keychain is locked; unlock it and retry"
            case errSecMissingEntitlement:
                "the app lacks the Keychain entitlement"
            default:
                "Keychain operation failed (status \(status))"
            }
        case .invalidItem:
            "Keychain item was not readable as text"
        }
    }
}

/// Stores secrets in the macOS Keychain, service `com.yurioliveira.yochamps`.
/// Config and logs hold only the `secretRef` used as the Keychain account.
public struct KeychainSecretStore: SecretStore {
    public static let defaultService = "com.yurioliveira.yochamps"

    private let service: String

    public init(service: String = KeychainSecretStore.defaultService) {
        self.service = service
    }

    public func secret(for ref: String) async throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: ref,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainError.operation(status)
        }
        guard let data = item as? Data, let text = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidItem
        }
        return text
    }

    public func setSecret(_ value: String?, for ref: String) async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: ref,
        ]
        guard let value else {
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw KeychainError.operation(status)
            }
            return
        }

        let data = Data(value.utf8)
        let update: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            if addStatus == errSecDuplicateItem {
                // Another writer created the item between update and add.
                let retry = SecItemUpdate(query as CFDictionary, update as CFDictionary)
                guard retry == errSecSuccess else { throw KeychainError.operation(retry) }
            } else {
                guard addStatus == errSecSuccess else { throw KeychainError.operation(addStatus) }
            }
        } else {
            guard updateStatus == errSecSuccess else {
                throw KeychainError.operation(updateStatus)
            }
        }
    }
}
