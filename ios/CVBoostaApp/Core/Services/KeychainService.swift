import Foundation
import Security

enum KeychainError: Error {
    case unexpectedStatus(OSStatus)
    case invalidData
}

final class KeychainService {
    static let shared = KeychainService()

    private let service = "com.cvboosta.auth"

    private init() {}

    func set(_ value: Data, for key: String) throws {
        var query = baseQuery(for: key)
        let attributes: [String: Any] = [kSecValueData as String: value]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecSuccess {
            return
        }

        if status == errSecItemNotFound {
            query[kSecValueData as String] = value
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unexpectedStatus(addStatus)
            }
            return
        }

        throw KeychainError.unexpectedStatus(status)
    }

    func set(_ value: String, for key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        try set(data, for: key)
    }

    func getData(for key: String) throws -> Data? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
        guard let data = item as? Data else {
            throw KeychainError.invalidData
        }
        return data
    }

    func getString(for key: String) throws -> String? {
        guard let data = try getData(for: key) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func delete(_ key: String) throws {
        let status = SecItemDelete(baseQuery(for: key) as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound {
            return
        }
        throw KeychainError.unexpectedStatus(status)
    }

    private func baseQuery(for key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
    }
}
