//
// IdentityStore.swift
// Author: Maru
//

import Combine
import Foundation
import Security

enum IdentityStoreError: LocalizedError {
    case invalidUserHash
    case invalidFeedID
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidUserHash:
            return "userhash 只能包含字母、数字以及 . _ ~ -"
        case .invalidFeedID:
            return "Feed ID 必须是有效的 UUID"
        case .keychain:
            return "无法访问设备钥匙串，请稍后重试"
        }
    }
}

@MainActor
final class IdentityStore: ObservableObject {
    @Published private(set) var userHash: String
    @Published private(set) var feedID: String

    private let storesPersistently: Bool

    var hasIdentity: Bool { userHash.nilIfBlank != nil }

    init() {
        storesPersistently = true
        if let stored = KeychainStore.read(key: "userhash"),
           let normalized = try? Self.normalizeUserHash(stored) {
            userHash = normalized
        } else {
            userHash = ""
            KeychainStore.delete(key: "userhash")
        }
        if let saved = UserDefaults.standard.string(forKey: "feedID"),
           let uuid = UUID(uuidString: saved) {
            feedID = uuid.uuidString.lowercased()
        } else {
            let generated = UUID().uuidString.lowercased()
            feedID = generated
            UserDefaults.standard.set(generated, forKey: "feedID")
        }
    }


    init(previewUserHash: String, feedID: String) {
        storesPersistently = false
        userHash = previewUserHash
        self.feedID = feedID
    }

    func save(userHash rawUserHash: String, feedID rawFeedID: String) throws {
        let userHash = try Self.normalizeUserHash(rawUserHash)
        guard let uuid = UUID(uuidString: rawFeedID.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw IdentityStoreError.invalidFeedID
        }
        let feedID = uuid.uuidString.lowercased()
        if storesPersistently {
            try KeychainStore.save(userHash, key: "userhash")
            UserDefaults.standard.set(feedID, forKey: "feedID")
        }
        self.userHash = userHash
        self.feedID = feedID
    }

    func clearIdentity() {
        if storesPersistently {
            KeychainStore.delete(key: "userhash")
        }
        userHash = ""
    }

    static func normalizeUserHash(_ rawValue: String) throws -> String {
        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmedValue),
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let value = components.queryItems?.first(where: {
               $0.name.caseInsensitiveCompare("userhash") == .orderedSame
           })?.value {
            return try normalizeUserHash(value)
        }
        if let data = trimmedValue.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let value = object.first(where: {
               $0.key.caseInsensitiveCompare("userhash") == .orderedSame
           })?.value as? String {
            return try normalizeUserHash(value)
        }

        let cookieParts = rawValue.split(separator: ";", omittingEmptySubsequences: true)
        let candidate = cookieParts.lazy.compactMap { part -> String? in
            let value = String(part).trimmingCharacters(in: .whitespacesAndNewlines)
            guard let separator = value.firstIndex(of: "=") else { return nil }
            let name = value[..<separator].trimmingCharacters(in: .whitespacesAndNewlines)
            guard name.caseInsensitiveCompare("userhash") == .orderedSame else { return nil }
            return String(value[value.index(after: separator)...])
        }.first ?? rawValue

        let result = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._~-")
        guard !result.isEmpty,
              result.count <= 512,
              result.unicodeScalars.allSatisfy(allowed.contains) else {
            throw IdentityStoreError.invalidUserHash
        }
        return result
    }
}

private enum KeychainStore {
    private static let service = "Xdnmb.Identity"
    private static let legacyService = "Xdnmb"

    static func save(_ value: String, key: String) throws {
        let data = Data(value.utf8)
        let matchQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let updateStatus = SecItemUpdate(
            matchQuery as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecSuccess {
            delete(key: key, service: legacyService)
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw IdentityStoreError.keychain(updateStatus)
        }

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else { throw IdentityStoreError.keychain(status) }
        delete(key: key, service: legacyService)
    }

    static func read(key: String) -> String? {
        read(key: key, service: service) ?? read(key: key, service: legacyService)
    }

    private static func read(key: String, service: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(key: String) {
        delete(key: key, service: service)
        delete(key: key, service: legacyService)
    }

    private static func delete(key: String, service: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
