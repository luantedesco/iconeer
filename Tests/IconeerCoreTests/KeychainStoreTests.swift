import Foundation
import Security
import Testing

@testable import IconeerCore

// Each test uses its own service name and deletes it, so the real key is never touched.
func testKeychain() -> KeychainStore {
    KeychainStore(service: "Iconeer tests \(UUID().uuidString)")
}

@Test func savedKeyIsReadBack() throws {
    let keychain = testKeychain()
    defer { keychain.delete() }

    try keychain.save("first-key")

    #expect(keychain.read() == "first-key")
}

@Test func savingAgainReplacesTheKey() throws {
    let keychain = testKeychain()
    defer { keychain.delete() }

    try keychain.save("first-key")
    try keychain.save("second-key")

    #expect(keychain.read() == "second-key")
}

@Test func deletedKeyIsGone() throws {
    let keychain = testKeychain()
    try keychain.save("first-key")

    keychain.delete()

    #expect(keychain.read() == nil)
}

@Test func keyLivesInTheKeychainAsAGenericPassword() throws {
    let keychain = testKeychain()
    defer { keychain.delete() }
    try keychain.save("first-key")

    var result: CFTypeRef?
    let status = SecItemCopyMatching(
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychain.service,
            kSecReturnData as String: true,
        ] as CFDictionary, &result)

    #expect(status == errSecSuccess)
    #expect((result as? Data).flatMap { String(data: $0, encoding: .utf8) } == "first-key")
}
