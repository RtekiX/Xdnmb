//
// APIServiceIntegrationTests.swift
// Author: Maru
//

import Foundation

@main
struct APIServiceIntegrationTests {
    static func main() async throws {
        let service = APIService()
        await service.bootstrap()

        async let groupRequest = service.forumGroups()
        async let timelineRequest = service.timelines()
        async let noticeRequest = service.notice()

        let groups = try await groupRequest
        let timelines = try await timelineRequest
        let notice = try await noticeRequest
        try require(!groups.isEmpty, "service returned no forum groups")
        try require(!timelines.isEmpty, "service returned no timelines")
        try require(notice.content.nilIfBlank != nil, "service returned an empty notice")

        let timelineThreads = try await service.timelineThreads(id: timelines[0].id, page: 1)
        try require(!timelineThreads.isEmpty, "service returned no timeline threads")

        guard let forum = groups.flatMap(\.visibleForums).first else {
            throw IntegrationError.failed("service returned no browsable forum")
        }
        let forumThreads = try await service.forumThreads(id: forum.id, page: 1)
        try require(!forumThreads.isEmpty, "service returned no forum threads")

        let detail = try await service.thread(id: timelineThreads[0].id, page: 1, onlyPO: false)
        try require(detail.id == timelineThreads[0].id, "service returned the wrong thread")
        let poDetail = try await service.thread(id: timelineThreads[0].id, page: 1, onlyPO: true)
        try require(poDetail.id == timelineThreads[0].id, "service returned the wrong PO-only thread")

        if let replyID = detail.replies.first(where: { $0.id > 0 && $0.id != 9_999_999 })?.id {
            let post = try await service.reference(id: replyID)
            try require(post.id == replyID, "service returned the wrong reference")
        }

        let feed = try await service.feed(id: UUID().uuidString, page: 1)
        try require(feed.allSatisfy { $0.id > 0 }, "service retained invalid feed entries")

        if let post = timelineThreads.first(where: { $0.post.hasImage })?.post {
            let imageURL = APIService.imageURL(
                path: post.imagePath,
                extension: post.imageExtension
            )
            try require(imageURL?.scheme == "https", "service produced an invalid image URL")
        }

        try require(
            APIService.imageURL(path: "../private", extension: ".jpg") == nil,
            "service must reject unsafe image paths"
        )
        do {
            _ = try await service.feed(id: "not-a-uuid", page: 1)
            throw IntegrationError.failed("service accepted an invalid Feed ID")
        } catch APIError.invalidFeedID {
            // Expected local validation failure.
        }

        let fallbackService = APIService(baseURL: URL(string: "https://127.0.0.1:1/")!)
        let fallbackTimelines = try await fallbackService.timelines()
        try require(!fallbackTimelines.isEmpty, "service did not recover through the backup API")

        print("API service passed: \(groups.count) groups, \(timelines.count) timelines, \(timelineThreads.count) timeline threads, \(forumThreads.count) forum threads, \(detail.replies.count) replies, backup recovery verified")
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw IntegrationError.failed(message) }
    }
}

private enum IntegrationError: LocalizedError {
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .failed(let message): return message
        }
    }
}
