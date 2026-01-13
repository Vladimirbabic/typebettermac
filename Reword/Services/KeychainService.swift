import Foundation
import Security
import OSLog

final class KeychainService: @unchecked Sendable {
    static let shared = KeychainService()

    private let queue = DispatchQueue(label: "com.reword.keychain", qos: .userInitiated)
    private var keyCache: [String: String] = [:]

    /// Keychain access group - uses App Identifier Prefix (Team ID) when signed
    /// Format: $(AppIdentifierPrefix)com.reword.app → e.g., "ABC123DEF4.com.reword.app"
    private var accessGroup: String? {
        // When app is properly signed, use the access group from entitlements
        // This prevents keychain prompts after distribution
        (Bundle.main.object(forInfoDictionaryKey: "AppIdentifierPrefix") as? String)
            .map { "\($0)com.reword.app" }
    }

    private init() {
        preloadKeys()
    }

    private func preloadKeys() {
        queue.sync {
            for provider in AIProvider.allCases {
                if let key = loadFromKeychainUnsafe(key: provider.keychainKey) {
                    keyCache[provider.keychainKey] = key
                    Logger.keychain.debug("Preloaded key for \(provider.displayName)")
                }
            }
        }
    }

    @discardableResult
    func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else {
            Logger.keychain.error("Failed to encode value for key: \(key)")
            return false
        }

        return queue.sync {
            keyCache[key] = value
            deleteFromKeychainUnsafe(key: key)

            var query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key,
                kSecAttrService as String: AppConstants.keychainService,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
            ]

            // Add access group when app is signed (prevents keychain prompts)
            if let group = accessGroup {
                query[kSecAttrAccessGroup as String] = group
            }

            let status = SecItemAdd(query as CFDictionary, nil)
            if status == errSecSuccess {
                Logger.keychain.debug("Saved key: \(key)")
                return true
            } else {
                Logger.keychain.error("Failed to save key: \(key), status: \(status)")
                return false
            }
        }
    }

    func get(key: String) -> String? {
        queue.sync {
            keyCache[key]
        }
    }

    private func loadFromKeychainUnsafe(key: String) -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: AppConstants.keychainService,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        if let group = accessGroup {
            query[kSecAttrAccessGroup as String] = group
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    @discardableResult
    func delete(key: String) -> Bool {
        queue.sync {
            keyCache.removeValue(forKey: key)
            return deleteFromKeychainUnsafe(key: key)
        }
    }

    @discardableResult
    private func deleteFromKeychainUnsafe(key: String) -> Bool {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: AppConstants.keychainService
        ]

        if let group = accessGroup {
            query[kSecAttrAccessGroup as String] = group
        }

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Convenience methods for AI providers

    @discardableResult
    func saveAPIKey(for provider: AIProvider, key: String) -> Bool {
        save(key: provider.keychainKey, value: key)
    }

    func getAPIKey(for provider: AIProvider) -> String? {
        get(key: provider.keychainKey)
    }

    @discardableResult
    func deleteAPIKey(for provider: AIProvider) -> Bool {
        delete(key: provider.keychainKey)
    }
}
