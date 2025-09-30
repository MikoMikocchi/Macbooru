import Foundation
import Security

struct DanbooruCredentials: Equatable {
    var username: String?
    var apiKey: String?

    static let empty = DanbooruCredentials(username: nil, apiKey: nil)

    var sanitized: DanbooruCredentials {
        DanbooruCredentials(
            username: username?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            apiKey: apiKey?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        )
    }

    var hasCredentials: Bool {
        sanitized.username != nil && sanitized.apiKey != nil
    }

    func asConfig() -> DanbooruConfig {
        let clean = sanitized
        return DanbooruConfig(apiKey: clean.apiKey, username: clean.username)
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

enum CredentialsStoreError: Error {
    case unexpectedStatus(OSStatus)
}

protocol CredentialsPersisting {
    func load() -> DanbooruCredentials
    func save(_ credentials: DanbooruCredentials) throws
    func clear() throws
}

final class KeychainCredentialsStore: CredentialsPersisting {
    private let service = "Macbooru.Danbooru"
    private let usernameKey = "username"
    private let apiKeyKey = "apiKey"

    func load() -> DanbooruCredentials {
        let username = try? read(key: usernameKey)
        let apiKey = try? read(key: apiKeyKey)
        return DanbooruCredentials(username: username, apiKey: apiKey)
    }

    func save(_ credentials: DanbooruCredentials) throws {
        let clean = credentials.sanitized
        if clean.username == nil { try delete(key: usernameKey) }
        if clean.apiKey == nil { try delete(key: apiKeyKey) }

        if let username = clean.username {
            if try exists(key: usernameKey) {
                try update(key: usernameKey, value: username)
            } else {
                try add(key: usernameKey, value: username)
            }
        }
        if let apiKey = clean.apiKey {
            if try exists(key: apiKeyKey) {
                try update(key: apiKeyKey, value: apiKey)
            } else {
                try add(key: apiKeyKey, value: apiKey)
            }
        }
    }

    func clear() throws {
        try delete(key: usernameKey)
        try delete(key: apiKeyKey)
    }

    // MARK: - Keychain helpers

    private func query(for key: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        #if os(macOS)
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        #endif
        return query
    }

    private func read(key: String) throws -> String? {
        var query = self.query(for: key)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = true

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else { throw CredentialsStoreError.unexpectedStatus(status) }
        guard let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func exists(key: String) throws -> Bool {
        var query = self.query(for: key)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        if status == errSecSuccess { return true }
        if status == errSecItemNotFound { return false }
        throw CredentialsStoreError.unexpectedStatus(status)
    }

    private func add(key: String, value: String) throws {
        var query = self.query(for: key)
        query[kSecValueData as String] = value.data(using: .utf8)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw CredentialsStoreError.unexpectedStatus(status) }
    }

    private func update(key: String, value: String) throws {
        let query = self.query(for: key)
        let attributes: [String: Any] = [kSecValueData as String: value.data(using: .utf8) ?? Data()]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        guard status == errSecSuccess else { throw CredentialsStoreError.unexpectedStatus(status) }
    }

    private func delete(key: String) throws {
        let query = self.query(for: key)
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecItemNotFound || status == errSecSuccess {
            return
        }
        throw CredentialsStoreError.unexpectedStatus(status)
    }
}

final class InMemoryCredentialsStore: CredentialsPersisting {
    private var credentials: DanbooruCredentials

    init(initial: DanbooruCredentials = .empty) {
        credentials = initial.sanitized
    }

    func load() -> DanbooruCredentials { credentials }

    func save(_ credentials: DanbooruCredentials) throws {
        self.credentials = credentials.sanitized
    }

    func clear() throws {
        credentials = .empty
    }
}
