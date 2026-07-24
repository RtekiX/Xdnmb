//
// ThreadListStoreStateTests.swift
// Author: Maru
//

import Foundation

@main
struct ThreadListStoreStateTests {
    static func main() async throws {
        let apiClient = ThreadListMockAPIClient()
        let store = await MainActor.run {
            ThreadListStore(apiClient: apiClient, runtimeMode: .live)
        }
        let source = ThreadListSource.timeline(id: 1, maximumPage: 3)

        await store.activate(source: source, userHash: "reader-a")
        var requestedPages = await apiClient.requestedTimelinePages
        try require(requestedPages == [1], "initial activation must load page 1")

        await store.activate(source: source, userHash: "reader-a")
        requestedPages = await apiClient.requestedTimelinePages
        try require(
            requestedPages == [1],
            "reactivating the same session must not reload after navigation return"
        )

        await store.loadMore()
        requestedPages = await apiClient.requestedTimelinePages
        try require(requestedPages == [1, 2], "load more must request the next page once")
        let retainedIDs = await MainActor.run { store.threads.map(\.id) }
        try require(retainedIDs == [101, 102], "pagination must retain prior items and append unique items")

        await store.activate(source: source, userHash: "reader-a")
        requestedPages = await apiClient.requestedTimelinePages
        try require(
            requestedPages == [1, 2],
            "returning after pagination must retain the loaded session"
        )

        await store.loadMore()
        let canLoadAfterEmptyPage = await MainActor.run { store.canLoadMore }
        try require(!canLoadAfterEmptyPage, "an empty page must stop automatic pagination")

        await store.refresh()
        requestedPages = await apiClient.requestedTimelinePages
        try require(
            requestedPages == [1, 2, 3, 1],
            "explicit refresh must remain available"
        )

        await store.activate(source: source, userHash: "reader-b")
        requestedPages = await apiClient.requestedTimelinePages
        try require(
            requestedPages == [1, 2, 3, 1, 1],
            "changing browsing identity must create a new request context"
        )

        await apiClient.failNextTimelineRequest()
        await store.loadMore()
        let failedState = await MainActor.run {
            (store.canLoadMore, store.errorMessage)
        }
        try require(!failedState.0 && failedState.1 != nil, "a failed page must stop automatic retries")

        await store.retry()
        requestedPages = await apiClient.requestedTimelinePages
        try require(
            requestedPages == [1, 2, 3, 1, 1, 2, 2],
            "manual retry must repeat the failed page exactly once"
        )

        try await verifyThreadStore(apiClient: apiClient)
        try await verifyComposerStore(apiClient: apiClient)
        try await verifyPostHistoryStore()

        print("Feature store state tests passed")
    }

    private static func verifyThreadStore(apiClient: ThreadListMockAPIClient) async throws {
        let store = await MainActor.run {
            ThreadStore(threadID: 101, apiClient: apiClient, runtimeMode: .live)
        }
        await store.activate(userHash: "reader-a")
        await store.activate(userHash: "reader-a")
        var requests = await apiClient.requestedThreadPages
        try require(requests == [1], "thread activation must be idempotent after navigation return")

        await store.nextPage()
        requests = await apiClient.requestedThreadPages
        try require(requests == [1, 2], "thread pagination must request the selected page")

        let subscribed = try await store.updateSubscription(
            currentlySubscribed: false,
            feedID: UUID().uuidString,
            userHash: "reader-a"
        )
        try require(subscribed, "subscription action must report the resulting state")

        let unsubscribed = try await store.updateSubscription(
            currentlySubscribed: true,
            feedID: UUID().uuidString,
            userHash: "reader-a"
        )
        try require(!unsubscribed, "unsubscription action must report the resulting state")
    }

    private static func verifyComposerStore(apiClient: ThreadListMockAPIClient) async throws {
        let store = await MainActor.run {
            ComposerStore(apiClient: apiClient, runtimeMode: .live)
        }
        let draft = ComposerDraft(
            content: "test",
            title: "",
            name: "",
            imageData: nil,
            imageExtension: nil
        )
        let threadSubmission = await store.submit(
            destination: .forum(4),
            draft: draft,
            userHash: "writer-a"
        )
        let replySubmission = await store.submit(
            destination: .thread(101),
            draft: draft,
            userHash: "writer-a"
        )
        try require(
            threadSubmission?.threadID == 202 && replySubmission?.threadID == 101,
            "composer actions must return both successful destinations"
        )
        let destinations = await apiClient.submittedDestinations
        try require(destinations == ["forum-4", "thread-101"], "composer must preserve its destination")
    }

    private static func verifyPostHistoryStore() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("XdnmbPostHistoryTests-\(UUID().uuidString)", isDirectory: true)
        let storageURL = directory.appendingPathComponent("history.json")
        defer { try? FileManager.default.removeItem(at: directory) }

        let entry = PostHistoryEntry(
            id: UUID(),
            kind: .reply,
            createdAt: Date(),
            threadID: 101,
            forumID: nil,
            forumName: nil,
            title: "",
            content: "local reply",
            authorName: "",
            hasAttachment: false
        )
        let store = await MainActor.run { PostHistoryStore(storageURL: storageURL) }
        await MainActor.run { store.record(entry) }
        let reloaded = await MainActor.run { PostHistoryStore(storageURL: storageURL) }
        let persistedEntries = await MainActor.run { reloaded.entries }
        try require(
            persistedEntries.count == 1 &&
                persistedEntries[0].id == entry.id &&
                persistedEntries[0].threadID == entry.threadID &&
                persistedEntries[0].content == entry.content,
            "post history must persist successful submissions"
        )

        await MainActor.run { reloaded.remove(id: entry.id) }
        let emptyReload = await MainActor.run { PostHistoryStore(storageURL: storageURL) }
        let remainingEntries = await MainActor.run { emptyReload.entries }
        try require(remainingEntries.isEmpty, "post history deletion must persist")
    }

    private static func require(_ condition: Bool, _ message: String) throws {
        guard condition else { throw ThreadListStateTestError.failed(message) }
    }
}

private enum ThreadListStateTestError: LocalizedError {
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .failed(let message): return message
        }
    }
}

private actor ThreadListMockAPIClient: XdnmbAPIClient {
    private(set) var requestedTimelinePages: [Int] = []
    private(set) var requestedThreadPages: [Int] = []
    private(set) var submittedDestinations: [String] = []
    private var shouldFailNextTimelineRequest = false
    private var lastPostRequestCount = 0

    func failNextTimelineRequest() {
        shouldFailNextTimelineRequest = true
    }

    func bootstrap() async {}
    func forumGroups(userHash: String?) async throws -> [ForumCategory] { [] }
    func timelines(userHash: String?) async throws -> [Timeline] { [] }
    func notice() async throws -> SiteNotice { throw ThreadListStateTestError.failed("unused endpoint") }

    func timelineThreads(id: Int, page: Int, userHash: String?) async throws -> [ForumThread] {
        requestedTimelinePages.append(page)
        if shouldFailNextTimelineRequest {
            shouldFailNextTimelineRequest = false
            throw ThreadListStateTestError.failed("expected request failure")
        }
        switch page {
        case 1: return [Self.thread(id: 101)]
        case 2: return [Self.thread(id: 102)]
        default: return []
        }
    }

    func forumThreads(id: Int, page: Int, userHash: String?) async throws -> [ForumThread] { [] }
    func thread(id: Int, page: Int, onlyPO: Bool, userHash: String?) async throws -> ThreadDetail {
        requestedThreadPages.append(page)
        let root = Self.thread(id: id).post
        let pagedRoot = Post(
            id: root.id,
            forumID: root.forumID,
            replyCount: 20,
            imagePath: root.imagePath,
            imageExtension: root.imageExtension,
            createdAt: root.createdAt,
            userHash: root.userHash,
            name: root.name,
            title: root.title,
            content: root.content,
            sage: root.sage,
            admin: root.admin,
            hidden: root.hidden
        )
        return ThreadDetail(post: pagedRoot, replies: [])
    }
    func reference(id: Int, userHash: String?) async throws -> Post {
        throw ThreadListStateTestError.failed("unused endpoint")
    }
    func lastPost(userHash: String) async throws -> LastPost {
        lastPostRequestCount += 1
        if lastPostRequestCount == 1 {
            return LastPost(parentThreadID: 0, id: 99, content: "previous")
        }
        return LastPost(parentThreadID: 0, id: 202, content: "test")
    }
    func feed(id: String, page: Int, userHash: String?) async throws -> [FeedEntry] { [] }
    func addFeed(feedID: String, threadID: Int, userHash: String) async throws -> String { "added" }
    func deleteFeed(feedID: String, threadID: Int, userHash: String) async throws -> String { "deleted" }

    func createThread(
        forumID: Int,
        content: String,
        title: String,
        name: String,
        imageData: Data?,
        imageExtension: String?,
        userHash: String
    ) async throws {
        submittedDestinations.append("forum-\(forumID)")
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
        submittedDestinations.append("thread-\(threadID)")
    }

    private static func thread(id: Int) -> ForumThread {
        ForumThread(
            post: Post(
                id: id,
                forumID: 4,
                replyCount: 0,
                imagePath: "",
                imageExtension: "",
                createdAt: "2026-07-22 12:00:00",
                userHash: "test",
                name: "",
                title: "",
                content: "test",
                sage: false,
                admin: false,
                hidden: false
            ),
            replies: [],
            remainReplies: 0
        )
    }
}
