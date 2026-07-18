//
// APIContractSmokeTests.swift
// Author: Maru
//

import Foundation

@main
struct APIContractSmokeTests {
    private static let decoder = JSONDecoder()
    private static let baseURL = URL(string: "https://www.nmbxd.com/")!

    static func main() async throws {
        try verifyDecoderEdgeCases()

        let groups: [ForumCategory] = try await decode(path: "Api/getForumList")
        try require(!groups.isEmpty, "forum groups must not be empty")
        try require(groups.flatMap(\.visibleForums).allSatisfy { $0.id > 0 }, "visible forums must have positive IDs")

        let timelines: [Timeline] = try await decode(path: "Api/getTimelineList")
        try require(!timelines.isEmpty, "timelines must not be empty")
        try require(timelines.allSatisfy { $0.id > 0 && $0.maxPage > 0 }, "timeline identifiers and pages must be valid")

        let timelineThreads: [ForumThread] = try await decode(
            path: "Api/timeline",
            query: ["id": String(timelines[0].id), "page": "1"]
        )
        try require(!timelineThreads.isEmpty, "timeline page must contain threads")
        try require(timelineThreads.allSatisfy { $0.id > 0 }, "timeline thread IDs must be positive")

        guard let forum = groups.flatMap(\.visibleForums).first else {
            throw ContractError.failed("a browsable forum is required")
        }
        let forumThreads: [ForumThread] = try await decode(
            path: "Api/showf",
            query: ["id": String(forum.id), "page": "1"]
        )
        try require(!forumThreads.isEmpty, "forum page must contain threads")

        let detail: ThreadDetail = try await decode(
            path: "Api/thread",
            query: ["id": String(timelineThreads[0].id), "page": "1"]
        )
        try require(detail.id == timelineThreads[0].id, "thread detail must match the requested thread")
        try require(detail.maxPage >= 1, "thread page count must be positive")

        let poDetail: ThreadDetail = try await decode(
            path: "Api/po",
            query: ["id": String(timelineThreads[0].id), "page": "1"]
        )
        try require(poDetail.id == timelineThreads[0].id, "PO-only detail must match the requested thread")

        if let replyID = detail.replies.first(where: { $0.id > 0 && $0.id != 9_999_999 })?.id {
            let reference: Post = try await decode(path: "Api/ref", query: ["id": String(replyID)])
            try require(reference.id == replyID, "reference endpoint must return the requested post")
        }

        let emptyFeedID = UUID().uuidString.lowercased()
        let feed: [FeedEntry] = try await decode(
            path: "Api/feed",
            query: ["uuid": emptyFeedID, "page": "1"]
        )
        try require(feed.allSatisfy { $0.id > 0 }, "feed entries must have valid IDs")

        let notice: SiteNotice = try await decode(url: URL(string: "https://nmb.ovear.info/nmb-notice.json")!)
        try require(notice.content.nilIfBlank != nil, "notice content must decode")
        try require(notice.date.nilIfBlank != nil, "numeric or string notice date must decode")

        let backups: [String] = try await decode(path: "Api/backupUrl")
        try require(backups.contains { URL(string: $0)?.scheme == "https" }, "an HTTPS backup endpoint is required")

        print("API contracts passed: \(groups.count) groups, \(timelines.count) timelines, \(timelineThreads.count) timeline threads, \(forumThreads.count) forum threads, \(detail.replies.count) replies, \(poDetail.replies.count) PO replies, \(feed.count) feed entries")
    }

    private static func verifyDecoderEdgeCases() throws {
        let noticeData = Data(#"{"content":"maintenance","date":2026042500007,"enable":1}"#.utf8)
        let notice = try decoder.decode(SiteNotice.self, from: noticeData)
        try require(notice.date == "2026042500007" && notice.enable, "mixed notice scalar types must decode")

        let threadData = Data(#"{"id":"42","fid":4,"ReplyCount":"2","img":"","ext":"","now":"now","user_hash":"hash","name":"","title":"无标题","content":"hello","sage":false,"admin":"0","Hide":0,"Replies":[{"id":9999999,"img":"","ext":"","now":"tips","user_hash":"Tips","name":"","title":"","content":"tip","admin":1},"invalid reply",null]}"#.utf8)
        let detail = try decoder.decode(ThreadDetail.self, from: threadData)
        try require(detail.id == 42, "string thread IDs must decode")
        try require(detail.replies.count == 1, "malformed reply elements must be skipped")
        try require(detail.replies[0].forumID == 0, "missing optional reply fields must use safe defaults")
    }

    private static func decode<Value: Decodable>(
        path: String,
        query: [String: String] = [:]
    ) async throws -> Value {
        var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = query.sorted(by: { $0.key < $1.key }).map {
            URLQueryItem(name: $0.key, value: $0.value)
        }
        guard let url = components.url else { throw ContractError.failed("invalid URL for \(path)") }
        return try await decode(url: url)
    }

    private static func decode<Value: Decodable>(url: URL) async throws -> Value {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let response = response as? HTTPURLResponse,
              (200..<300).contains(response.statusCode) else {
            throw ContractError.failed("HTTP request failed for \(url.absoluteString)")
        }
        do {
            return try decoder.decode(Value.self, from: data)
        } catch {
            throw ContractError.failed("decoding failed for \(url.absoluteString): \(error)")
        }
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw ContractError.failed(message) }
    }
}

private enum ContractError: LocalizedError {
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .failed(let message): return message
        }
    }
}
