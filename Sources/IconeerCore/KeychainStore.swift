import Foundation
import Security

// The user's macOSicons API key, as a generic password in the login Keychain.
public struct KeychainStore: Sendable {
    let service: String
    let account: String

    public init(service: String = "Iconeer", account: String = "macosicons-api-key") {
        self.service = service
        self.account = account
    }

    var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    }

    public func read() -> String? {
        var result: CFTypeRef?
        var search = query
        search[kSecReturnData as String] = true
        guard SecItemCopyMatching(search as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // Replaces the stored key, if any.
    public func save(_ key: String) throws {
        delete()
        var item = query
        item[kSecValueData as String] = Data(key.utf8)
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }

    public func delete() {
        SecItemDelete(query as CFDictionary)
    }
}

public struct KeychainError: Error, Equatable {
    public var status: OSStatus
}
