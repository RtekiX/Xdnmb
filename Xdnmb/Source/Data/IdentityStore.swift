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
    case cookieLimitReached
    case duplicateCookie
    case cookieNotFound
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidUserHash:
            return "userhash 只能包含字母、数字以及 . _ ~ -"
        case .invalidFeedID:
            return "Feed ID 必须是有效的 UUID"
        case .cookieLimitReached:
            return "最多只能保存 5 个饼干"
        case .duplicateCookie:
            return "这个饼干已经导入"
        case .cookieNotFound:
            return "找不到这个饼干，请刷新后重试"
        case .keychain:
            return "无法访问设备钥匙串，请稍后重试"
        }
    }
}

struct IdentityCookie: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let userHash: String

    var maskedUserHash: String {
        "••••" + userHash.suffix(6)
    }
}

private struct StoredIdentityCollection: Codable {
    let cookies: [IdentityCookie]
    let browsingCookieID: UUID?
    let postingCookieID: UUID?
}

@MainActor
final class IdentityStore: ObservableObject {
    static let maximumCookieCount = 5

    @Published private(set) var cookies: [IdentityCookie]
    @Published private(set) var browsingCookieID: UUID?
    @Published private(set) var postingCookieID: UUID?
    @Published private(set) var feedID: String

    private static let collectionKey = "identityCookies.v2"
    private let storesPersistently: Bool

    var hasIdentity: Bool { !cookies.isEmpty }
    var canImportCookie: Bool { cookies.count < Self.maximumCookieCount }
    var browsingCookie: IdentityCookie? { cookie(id: browsingCookieID) }
    var postingCookie: IdentityCookie? { cookie(id: postingCookieID) }
    var browsingUserHash: String? { browsingCookie?.userHash }
    var postingUserHash: String? { postingCookie?.userHash }

    init() {
        storesPersistently = true
        if let stored = Self.loadCollection() {
            cookies = stored.cookies
            browsingCookieID = Self.validPrimaryID(stored.browsingCookieID, in: stored.cookies)
            postingCookieID = Self.validPrimaryID(stored.postingCookieID, in: stored.cookies)
            KeychainStore.delete(key: "userhash")
        } else if let legacyHash = KeychainStore.read(key: "userhash"),
                  let normalized = try? Self.normalizeUserHash(legacyHash) {
            let migratedCookie = IdentityCookie(
                id: UUID(),
                name: "饼干 1",
                userHash: normalized
            )
            cookies = [migratedCookie]
            browsingCookieID = migratedCookie.id
            postingCookieID = migratedCookie.id
            let migrated = StoredIdentityCollection(
                cookies: [migratedCookie],
                browsingCookieID: migratedCookie.id,
                postingCookieID: migratedCookie.id
            )
            if (try? Self.persist(migrated)) != nil {
                KeychainStore.delete(key: "userhash")
            }
        } else {
            cookies = []
            browsingCookieID = nil
            postingCookieID = nil
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
        let browsingCookie = IdentityCookie(
            id: UUID(),
            name: "Preview 饼干 1",
            userHash: previewUserHash
        )
        let postingCookie = IdentityCookie(
            id: UUID(),
            name: "Preview 饼干 2",
            userHash: "\(previewUserHash)_alt"
        )
        cookies = [browsingCookie, postingCookie]
        browsingCookieID = browsingCookie.id
        postingCookieID = postingCookie.id
        self.feedID = feedID
    }

    @discardableResult
    func importCookie(fromQRCode rawValue: String) throws -> IdentityCookie {
        let userHash = try Self.normalizeUserHash(rawValue)
        guard !cookies.contains(where: { $0.userHash == userHash }) else {
            throw IdentityStoreError.duplicateCookie
        }
        guard canImportCookie else { throw IdentityStoreError.cookieLimitReached }

        let cookie = IdentityCookie(
            id: UUID(),
            name: nextCookieName(),
            userHash: userHash
        )
        let newCookies = cookies + [cookie]
        try apply(
            cookies: newCookies,
            browsingCookieID: browsingCookieID ?? cookie.id,
            postingCookieID: postingCookieID ?? cookie.id
        )
        return cookie
    }

    func removeCookie(id: UUID) throws {
        guard cookies.contains(where: { $0.id == id }) else {
            throw IdentityStoreError.cookieNotFound
        }
        let remaining = cookies.filter { $0.id != id }
        try apply(
            cookies: remaining,
            browsingCookieID: browsingCookieID == id ? remaining.first?.id : browsingCookieID,
            postingCookieID: postingCookieID == id ? remaining.first?.id : postingCookieID
        )
    }

    func setBrowsingCookie(id: UUID) throws {
        guard cookies.contains(where: { $0.id == id }) else {
            throw IdentityStoreError.cookieNotFound
        }
        try apply(cookies: cookies, browsingCookieID: id, postingCookieID: postingCookieID)
    }

    func setPostingCookie(id: UUID) throws {
        guard cookies.contains(where: { $0.id == id }) else {
            throw IdentityStoreError.cookieNotFound
        }
        try apply(cookies: cookies, browsingCookieID: browsingCookieID, postingCookieID: id)
    }

    func saveFeedID(_ rawFeedID: String) throws {
        guard let uuid = UUID(uuidString: rawFeedID.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw IdentityStoreError.invalidFeedID
        }
        let feedID = uuid.uuidString.lowercased()
        if storesPersistently {
            UserDefaults.standard.set(feedID, forKey: "feedID")
        }
        self.feedID = feedID
    }

    func clearIdentity() {
        if storesPersistently {
            KeychainStore.delete(key: Self.collectionKey)
            KeychainStore.delete(key: "userhash")
        }
        cookies = []
        browsingCookieID = nil
        postingCookieID = nil
    }

    func cookie(id: UUID?) -> IdentityCookie? {
        guard let id else { return nil }
        return cookies.first { $0.id == id }
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

    private func nextCookieName() -> String {
        let names = Set(cookies.map(\.name))
        for index in 1...Self.maximumCookieCount {
            let name = "饼干 \(index)"
            if !names.contains(name) { return name }
        }
        return "饼干 \(cookies.count + 1)"
    }

    private func apply(
        cookies: [IdentityCookie],
        browsingCookieID: UUID?,
        postingCookieID: UUID?
    ) throws {
        let normalizedBrowsingID = Self.validPrimaryID(browsingCookieID, in: cookies)
        let normalizedPostingID = Self.validPrimaryID(postingCookieID, in: cookies)
        let collection = StoredIdentityCollection(
            cookies: cookies,
            browsingCookieID: normalizedBrowsingID,
            postingCookieID: normalizedPostingID
        )
        if storesPersistently {
            if cookies.isEmpty {
                KeychainStore.delete(key: Self.collectionKey)
            } else {
                try Self.persist(collection)
            }
        }
        self.cookies = cookies
        self.browsingCookieID = normalizedBrowsingID
        self.postingCookieID = normalizedPostingID
    }

    private static func validPrimaryID(_ candidate: UUID?, in cookies: [IdentityCookie]) -> UUID? {
        if let candidate, cookies.contains(where: { $0.id == candidate }) {
            return candidate
        }
        return cookies.first?.id
    }

    private static func loadCollection() -> StoredIdentityCollection? {
        guard let value = KeychainStore.read(key: collectionKey),
              let data = value.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(StoredIdentityCollection.self, from: data) else {
            return nil
        }

        var seenHashes = Set<String>()
        var seenIDs = Set<UUID>()
        let validCookies = decoded.cookies.prefix(maximumCookieCount).compactMap { cookie -> IdentityCookie? in
            guard let hash = try? normalizeUserHash(cookie.userHash),
                  seenHashes.insert(hash).inserted,
                  seenIDs.insert(cookie.id).inserted else { return nil }
            let name = cookie.name.nilIfBlank ?? "饼干 \(seenHashes.count)"
            return IdentityCookie(id: cookie.id, name: name, userHash: hash)
        }
        guard !validCookies.isEmpty else { return nil }
        return StoredIdentityCollection(
            cookies: validCookies,
            browsingCookieID: validPrimaryID(decoded.browsingCookieID, in: validCookies),
            postingCookieID: validPrimaryID(decoded.postingCookieID, in: validCookies)
        )
    }

    private static func persist(_ collection: StoredIdentityCollection) throws {
        let data = try JSONEncoder().encode(collection)
        guard let value = String(data: data, encoding: .utf8) else {
            throw IdentityStoreError.invalidUserHash
        }
        try KeychainStore.save(value, key: collectionKey)
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
