import Foundation
import Security

nonisolated
enum KeychainService {
    private static let service = "com.timmygram.api"
    private static let serverUrlAccount = "serverUrl"
    private static let tokenAccount = "jwtToken"
    private static let settingsPinAccount = "settingsPin"

    static func save(config: ServerConfig) throws {
        try save(value: config.serverUrl, account: serverUrlAccount)
        try save(value: config.token, account: tokenAccount)
    }

    static func loadConfig() -> ServerConfig? {
        guard let serverUrl = load(account: serverUrlAccount),
              let token = load(account: tokenAccount) else {
            return nil
        }
        return ServerConfig(serverUrl: serverUrl, token: token)
    }

    static func deleteConfig() {
        delete(account: serverUrlAccount)
        delete(account: tokenAccount)
        delete(account: settingsPinAccount)
    }

    static func saveSettingsPin(_ pin: String) throws {
        try save(value: pin, account: settingsPinAccount)
    }

    static func loadSettingsPin() -> String? {
        load(account: settingsPinAccount)
    }

    static func deleteSettingsPin() {
        delete(account: settingsPinAccount)
    }

    private static func save(value: String, account: String) throws {
        guard let data = value.data(using: .utf8) else { return }

        delete(account: account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    private static func load(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    private static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum KeychainError: Error {
    case saveFailed(OSStatus)
}
