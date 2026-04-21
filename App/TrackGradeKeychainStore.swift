import Foundation
import Security

struct TrackGradeKeychainStore {
    private let service = "com.example.trackgrade.credentials"

    func save(
        credentials: ColorBoxCredentials,
        reference: String
    ) throws {
        let payload = try JSONEncoder().encode(credentials)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: reference,
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: payload,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }

        if updateStatus != errSecItemNotFound {
            throw KeychainStoreError.unexpectedStatus(updateStatus)
        }

        var insertQuery = query
        insertQuery[kSecValueData as String] = payload
        let insertStatus = SecItemAdd(insertQuery as CFDictionary, nil)
        guard insertStatus == errSecSuccess else {
            throw KeychainStoreError.unexpectedStatus(insertStatus)
        }
    }

    func load(reference: String) throws -> ColorBoxCredentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: reference,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw KeychainStoreError.invalidPayload
            }
            return try JSONDecoder().decode(ColorBoxCredentials.self, from: data)
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainStoreError.unexpectedStatus(status)
        }
    }

    func delete(reference: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: reference,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainStoreError.unexpectedStatus(status)
        }
    }
}

enum KeychainStoreError: Error, LocalizedError {
    case invalidPayload
    case unexpectedStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidPayload:
            return "The Keychain returned an invalid credential payload."
        case let .unexpectedStatus(status):
            return "Keychain operation failed with status \(status)."
        }
    }
}
