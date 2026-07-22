//
// APIService.swift
// Author: Maru
//

import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case http(statusCode: Int, message: String?)
    case server(String)
    case decoding(endpoint: String)
    case invalidPayload(String)
    case transport(String)
    case missingIdentity
    case invalidIdentity
    case invalidFeedID
    case emptyContent
    case contentTooLong
    case attachmentTooLarge

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "请求地址无效"
        case .invalidResponse:
            return "服务器返回了无法识别的响应"
        case .http(let statusCode, let message):
            return message?.nilIfBlank ?? "请求失败（HTTP \(statusCode)）"
        case .server(let message):
            return message.nilIfBlank ?? "服务器拒绝了这次操作"
        case .decoding:
            return "服务器数据格式发生了变化，请稍后更新客户端"
        case .invalidPayload(let message):
            return message
        case .transport(let message):
            return message
        case .missingIdentity:
            return "请先在“我的”中导入饼干"
        case .invalidIdentity:
            return "userhash 格式无效，请重新导入"
        case .invalidFeedID:
            return "Feed ID 必须是有效的 UUID"
        case .emptyContent:
            return "请输入内容后再发送"
        case .contentTooLong:
            return "正文过长，请精简后再发送"
        case .attachmentTooLarge:
            return "图片超过 10 MB，请压缩后再发送"
        }
    }
}

actor APIService {
    static let shared = APIService()

    private static let defaultImageBaseURL = URL(string: "https://image.nmb.best/")!
    private static let maximumResponseSize = 20 * 1_024 * 1_024
    private static let maximumAttachmentSize = 10 * 1_024 * 1_024
    private static let maximumContentLength = 100_000

    private let originURL: URL
    private var baseURL: URL
    private var backupURL: URL
    private let noticeURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    init(
        session: URLSession? = nil,
        originURL: URL = URL(string: "https://www.nmbxd.com/")!,
        baseURL: URL = URL(string: "https://www.nmbxd1.com/")!,
        backupURL: URL = URL(string: "https://api.nmb.best/")!,
        noticeURL: URL = URL(string: "https://nmb.ovear.info/nmb-notice.json")!
    ) {
        self.originURL = originURL
        self.baseURL = baseURL
        self.backupURL = backupURL
        self.noticeURL = noticeURL
        decoder = JSONDecoder()

        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 20
            configuration.timeoutIntervalForResource = 45
            configuration.waitsForConnectivity = true
            configuration.requestCachePolicy = .reloadRevalidatingCacheData
            configuration.httpShouldSetCookies = false
            configuration.httpCookieStorage = nil
            configuration.httpAdditionalHeaders = [
                "Accept": "application/json,text/plain,*/*",
                "User-Agent": "Xdnmb-iOS/1.0"
            ]
            self.session = URLSession(configuration: configuration)
        }
    }

    nonisolated static func imageURL(path: String, extension fileExtension: String, original: Bool = false) -> URL? {
        let cleanPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        let cleanExtension = fileExtension.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanPath.nilIfBlank != nil,
              cleanExtension.nilIfBlank != nil,
              !cleanPath.contains(".."),
              !cleanExtension.contains("/"),
              !cleanExtension.contains("..") else { return nil }

        let normalizedExtension = cleanExtension.hasPrefix(".") ? cleanExtension : ".\(cleanExtension)"
        return defaultImageBaseURL
            .appendingPathComponent(original ? "image" : "thumb", isDirectory: true)
            .appendingPathComponent(cleanPath + normalizedExtension)
    }

    func bootstrap() async {
        await discoverPrimaryServer()
        await discoverBackupServer()
    }

    func forumGroups(userHash: String? = nil) async throws -> [ForumCategory] {
        let groups: [ForumCategory] = try await get("Api/getForumList", userHash: userHash)
        return groups
            .filter { $0.id > 0 && $0.name.nilIfBlank != nil }
            .sorted { ($0.sort, $0.id) < ($1.sort, $1.id) }
    }

    func timelines(userHash: String? = nil) async throws -> [Timeline] {
        let values: [Timeline] = try await get("Api/getTimelineList", userHash: userHash)
        return values.filter { $0.id > 0 && $0.displayName.nilIfBlank != nil }.deduplicatedByID()
    }

    func notice() async throws -> SiteNotice {
        try await decodeRequest(url: noticeURL, endpoint: "nmb-notice.json")
    }

    func timelineThreads(id: Int, page: Int, userHash: String? = nil) async throws -> [ForumThread] {
        guard id > 0 else { throw APIError.invalidPayload("时间线编号无效") }
        let values: [ForumThread] = try await get(
            "Api/timeline",
            query: ["id": String(id), "page": String(max(page, 1))],
            userHash: userHash
        )
        return values.filter { $0.id > 0 }.deduplicatedByID()
    }

    func forumThreads(id: Int, page: Int, userHash: String? = nil) async throws -> [ForumThread] {
        guard id > 0 else { throw APIError.invalidPayload("版块编号无效") }
        let values: [ForumThread] = try await get(
            "Api/showf",
            query: ["id": String(id), "page": String(max(page, 1))],
            userHash: userHash
        )
        return values.filter { $0.id > 0 }.deduplicatedByID()
    }

    func thread(id: Int, page: Int, onlyPO: Bool, userHash: String? = nil) async throws -> ThreadDetail {
        guard id > 0 else { throw APIError.invalidPayload("串号无效") }
        let detail: ThreadDetail = try await get(
            onlyPO ? "Api/po" : "Api/thread",
            query: ["id": String(id), "page": String(max(page, 1))],
            userHash: userHash
        )
        guard detail.id > 0 else { throw APIError.invalidPayload("服务器没有返回有效的帖子") }
        return detail
    }

    func reference(id: Int, userHash: String? = nil) async throws -> Post {
        guard id > 0 else { throw APIError.invalidPayload("引用编号无效") }
        let post: Post = try await get("Api/ref", query: ["id": String(id)], userHash: userHash)
        guard post.id > 0 else { throw APIError.invalidPayload("引用的帖子不存在") }
        return post
    }

    func lastPost(userHash: String) async throws -> LastPost {
        let hash = try Self.validatedUserHash(userHash)
        let url = try makeURL(base: baseURL, path: "Api/getLastPost", query: [:])
        let value: LastPost = try await decodeRequest(
            request: authenticatedRequest(url: url, userHash: hash),
            endpoint: "Api/getLastPost"
        )
        guard value.threadID > 0 else { throw APIError.invalidPayload("没有找到最近发送的帖子") }
        return value
    }

    func feed(id: String, page: Int, userHash: String? = nil) async throws -> [FeedEntry] {
        let feedID = try Self.validatedFeedID(id)
        let values: [FeedEntry] = try await get(
            "Api/feed",
            query: ["uuid": feedID, "page": String(max(page, 1))],
            userHash: userHash
        )
        return values.filter { $0.id > 0 }.deduplicatedByID()
    }

    func addFeed(feedID: String, threadID: Int, userHash: String) async throws -> String {
        try await updateFeed(path: "Api/addFeed", feedID: feedID, threadID: threadID, userHash: userHash)
    }

    func deleteFeed(feedID: String, threadID: Int, userHash: String) async throws -> String {
        try await updateFeed(path: "Api/delFeed", feedID: feedID, threadID: threadID, userHash: userHash)
    }

    func createThread(
        forumID: Int,
        content: String,
        title: String,
        name: String,
        imageData: Data?,
        imageExtension: String?,
        userHash: String
    ) async throws {
        guard forumID > 0 else { throw APIError.invalidPayload("版块编号无效") }
        try validatePost(content: content, imageData: imageData)
        try await multipart(
            "Home/Forum/doPostThread.html",
            fields: [
                "fid": String(forumID), "content": content,
                "title": title, "name": name, "email": "", "water": "false"
            ],
            imageData: imageData,
            imageExtension: imageExtension,
            userHash: userHash
        )
    }

    func reply(
        threadID: Int,
        content: String,
        title: String,
        name: String,
        imageData: Data?,
        imageExtension: String?,
        userHash: String
    ) async throws {
        guard threadID > 0 else { throw APIError.invalidPayload("串号无效") }
        try validatePost(content: content, imageData: imageData)
        try await multipart(
            "Home/Forum/doReplyThread.html",
            fields: [
                "resto": String(threadID), "content": content,
                "title": title, "name": name, "email": "", "water": "false"
            ],
            imageData: imageData,
            imageExtension: imageExtension,
            userHash: userHash
        )
    }

    private func discoverPrimaryServer() async {
        guard let (_, response) = try? await session.data(from: originURL),
              let resolvedURL = response.url,
              let components = URLComponents(url: resolvedURL, resolvingAgainstBaseURL: false),
              let scheme = components.scheme,
              let host = components.host,
              let discovered = URL(string: "\(scheme)://\(host)/") else { return }
        baseURL = discovered
    }

    private func discoverBackupServer() async {
        guard let values: [String] = try? await get("Api/backupUrl"),
              let value = values.first,
              let discovered = URL(string: value),
              let scheme = discovered.scheme?.lowercased(),
              scheme == "https" else { return }
        backupURL = discovered
    }

    private func get<Value: Decodable & Sendable>(
        _ path: String,
        query: [String: String] = [:],
        userHash: String? = nil
    ) async throws -> Value {
        let hash = try userHash.map(Self.validatedUserHash)
        let primaryURL = try makeURL(base: baseURL, path: path, query: query)
        do {
            return try await decodeRequest(
                request: authenticatedRequest(url: primaryURL, userHash: hash),
                endpoint: path
            )
        } catch {
            if error is CancellationError { throw error }
            try Task.checkCancellation()
            let fallbackURL = try makeURL(base: backupURL, path: path, query: query)
            guard fallbackURL != primaryURL else { throw error }
            return try await decodeRequest(
                request: authenticatedRequest(url: fallbackURL, userHash: hash),
                endpoint: path
            )
        }
    }

    private func decodeRequest<Value: Decodable & Sendable>(url: URL, endpoint: String) async throws -> Value {
        try await decodeRequest(request: URLRequest(url: url), endpoint: endpoint)
    }

    private func decodeRequest<Value: Decodable & Sendable>(
        request: URLRequest,
        endpoint: String
    ) async throws -> Value {
        let data = try await data(for: request)
        if let message = serverErrorMessage(from: data) { throw APIError.server(message) }
        do {
            return try decoder.decode(Value.self, from: data)
        } catch {
            throw APIError.decoding(endpoint: endpoint)
        }
    }

    private func updateFeed(path: String, feedID: String, threadID: Int, userHash: String) async throws -> String {
        let feedID = try Self.validatedFeedID(feedID)
        let hash = try Self.validatedUserHash(userHash)
        guard threadID > 0 else { throw APIError.invalidPayload("串号无效") }
        let url = try makeURL(
            base: baseURL,
            path: path,
            query: ["uuid": feedID, "tid": String(threadID)]
        )
        let data = try await data(for: authenticatedRequest(url: url, userHash: hash))
        if let message = serverErrorMessage(from: data) { throw APIError.server(message) }
        return String(data: data, encoding: .utf8)?.htmlPlainText.nilIfBlank ?? "操作成功"
    }

    private func multipart(
        _ path: String,
        fields: [String: String],
        imageData: Data?,
        imageExtension: String?,
        userHash: String
    ) async throws {
        let hash = try Self.validatedUserHash(userHash)
        let boundary = "XdnmbBoundary-\(UUID().uuidString)"
        var body = Data()

        for (name, value) in fields.sorted(by: { $0.key < $1.key }) {
            body.appendUTF8("--\(boundary)\r\n")
            body.appendUTF8("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            body.appendUTF8("\(value)\r\n")
        }
        if let imageData {
            let fileExtension = Self.normalizedImageExtension(imageExtension)
            let mimeType: String
            switch fileExtension {
            case "png": mimeType = "image/png"
            case "gif": mimeType = "image/gif"
            default: mimeType = "image/jpeg"
            }
            body.appendUTF8("--\(boundary)\r\n")
            body.appendUTF8("Content-Disposition: form-data; name=\"image\"; filename=\"upload.\(fileExtension)\"\r\n")
            body.appendUTF8("Content-Type: \(mimeType)\r\n\r\n")
            body.append(imageData)
            body.appendUTF8("\r\n")
        }
        body.appendUTF8("--\(boundary)--\r\n")

        let url = try makeURL(base: baseURL, path: path, query: [:])
        var request = authenticatedRequest(url: url, userHash: hash)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        let data = try await data(for: request)
        if let message = serverErrorMessage(from: data) { throw APIError.server(message) }

        if let text = String(data: data, encoding: .utf8)?.htmlPlainText,
           text.count < 2_000,
           text.localizedCaseInsensitiveContains("错误") || text.localizedCaseInsensitiveContains("失败") {
            throw APIError.server(text)
        }
    }

    private func data(for request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)
            try Task.checkCancellation()
            guard let httpResponse = response as? HTTPURLResponse else { throw APIError.invalidResponse }
            guard (200..<300).contains(httpResponse.statusCode) else {
                let message = String(data: data.prefix(2_000), encoding: .utf8)?.htmlPlainText
                throw APIError.http(statusCode: httpResponse.statusCode, message: message)
            }
            guard data.count <= Self.maximumResponseSize else {
                throw APIError.invalidPayload("服务器响应过大，已停止处理")
            }
            return data
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as APIError {
            throw error
        } catch let error as URLError {
            throw APIError.transport(Self.transportMessage(for: error))
        } catch {
            throw APIError.transport("网络请求失败，请稍后重试")
        }
    }

    private func makeURL(base: URL, path: String, query: [String: String]) throws -> URL {
        let endpoint = base.appendingPathComponent(path)
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        components.queryItems = query.sorted(by: { $0.key < $1.key }).map {
            URLQueryItem(name: $0.key, value: $0.value)
        }
        guard let url = components.url else { throw APIError.invalidURL }
        return url
    }

    private func authenticatedRequest(url: URL, userHash: String?) -> URLRequest {
        var request = URLRequest(url: url)
        if let userHash {
            request.setValue("userhash=\(userHash)", forHTTPHeaderField: "Cookie")
        }
        return request
    }

    private func serverErrorMessage(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let success = object["success"] else { return nil }

        let succeeded: Bool?
        switch success {
        case let value as Bool: succeeded = value
        case let value as Int: succeeded = value != 0
        case let value as String:
            succeeded = ["1", "true", "success", "ok"].contains(value.lowercased())
        default: succeeded = nil
        }
        guard succeeded == false else { return nil }
        return (object["message"] as? String)?.htmlPlainText.nilIfBlank ?? "服务器拒绝了这次操作"
    }

    private func validatePost(content: String, imageData: Data?) throws {
        guard content.nilIfBlank != nil else { throw APIError.emptyContent }
        guard content.count <= Self.maximumContentLength else { throw APIError.contentTooLong }
        guard (imageData?.count ?? 0) <= Self.maximumAttachmentSize else { throw APIError.attachmentTooLarge }
    }

    private static func validatedUserHash(_ rawValue: String) throws -> String {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._~-")
        guard !value.isEmpty,
              value.count <= 512,
              value.unicodeScalars.allSatisfy(allowed.contains) else {
            throw APIError.invalidIdentity
        }
        return value
    }

    private static func validatedFeedID(_ rawValue: String) throws -> String {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let uuid = UUID(uuidString: value) else { throw APIError.invalidFeedID }
        return uuid.uuidString.lowercased()
    }

    private static func normalizedImageExtension(_ value: String?) -> String {
        guard let normalized = value?.trimmingCharacters(in: CharacterSet(charactersIn: ". ")).lowercased(),
              ["jpg", "jpeg", "png", "gif"].contains(normalized) else {
            return "jpg"
        }
        return normalized
    }

    private static func transportMessage(for error: URLError) -> String {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return "网络连接已断开，请检查网络后重试"
        case .timedOut:
            return "连接服务器超时，请稍后重试"
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return "暂时无法连接 X 岛服务器"
        default:
            return "网络请求失败，请稍后重试"
        }
    }
}

private extension Data {
    mutating func appendUTF8(_ string: String) {
        if let data = string.data(using: .utf8) { append(data) }
    }
}

private extension Array where Element: Identifiable, Element.ID: Hashable {
    func deduplicatedByID() -> [Element] {
        var ids = Set<Element.ID>()
        return filter { ids.insert($0.id).inserted }
    }
}
