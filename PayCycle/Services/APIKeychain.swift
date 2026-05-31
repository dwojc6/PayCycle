import Foundation
import Security

struct APIKeychain {
    private let service = "com.davidwojcik.PayCycle"
    private let lunchMoneyTokenAccount = "lunchmoney-api-token"
    private let simpleFINSetupURLAccount = "simplefin-setup-url"

    func saveToken(_ token: String) throws {
        try save(token, account: lunchMoneyTokenAccount)
    }

    func loadToken() throws -> String? {
        try load(account: lunchMoneyTokenAccount)
    }

    func deleteToken() throws {
        try delete(account: lunchMoneyTokenAccount)
    }

    func saveSimpleFINSetupURL(_ setupURL: String) throws {
        try save(setupURL, account: simpleFINSetupURLAccount)
    }

    func loadSimpleFINSetupURL() throws -> String? {
        try load(account: simpleFINSetupURLAccount)
    }

    func deleteSimpleFINSetupURL() throws {
        try delete(account: simpleFINSetupURLAccount)
    }

    private func save(_ value: String, account: String) throws {
        let data = Data(value.utf8)
        let query = baseQuery(account: account)

        SecItemDelete(query as CFDictionary)

        var item = query
        item[kSecValueData as String] = data

        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw APIKeychainError.saveFailed(status)
        }
    }

    private func load(account: String) throws -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data, let token = String(data: data, encoding: .utf8) else {
                return nil
            }
            return token
        case errSecItemNotFound:
            return nil
        default:
            throw APIKeychainError.loadFailed(status)
        }
    }

    private func delete(account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw APIKeychainError.deleteFailed(status)
        }
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

enum APIKeychainError: LocalizedError {
    case saveFailed(OSStatus)
    case loadFailed(OSStatus)
    case deleteFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .saveFailed:
            return "The Lunch Money token could not be saved to the keychain."
        case .loadFailed:
            return "The saved Lunch Money token could not be read from the keychain."
        case .deleteFailed:
            return "The saved Lunch Money token could not be removed from the keychain."
        }
    }
}
