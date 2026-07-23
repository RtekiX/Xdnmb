//
// AppModel.swift
// Author: Maru
//

import Combine
import Foundation

struct ThreadReadingPosition: Equatable {
    var page: Int
    var postID: Int?
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var forumGroups: [ForumCategory] = []
    @Published private(set) var timelines: [Timeline] = []
    @Published private(set) var notice: SiteNotice?
    @Published private(set) var isBootstrapping = false
    @Published private(set) var forumError: String?
    @Published private(set) var timelineError: String?
    @Published var subscribedThreadIDs: Set<Int> = []
    @Published private(set) var threadReadingPositions: [Int: ThreadReadingPosition] = [:]

    private let apiClient: any XdnmbAPIClient
    private var bootstrapToken = UUID()

    init(
        apiClient: any XdnmbAPIClient = APIService.shared,
        forumGroups: [ForumCategory] = [],
        timelines: [Timeline] = [],
        notice: SiteNotice? = nil,
        subscribedThreadIDs: Set<Int> = []
    ) {
        self.apiClient = apiClient
        self.forumGroups = forumGroups
        self.timelines = timelines
        self.notice = notice
        self.subscribedThreadIDs = subscribedThreadIDs
    }

    var isConnected: Bool {
        !forumGroups.isEmpty || !timelines.isEmpty
    }

    func bootstrap(userHash: String? = nil) async {
        let token = UUID()
        bootstrapToken = token
        isBootstrapping = true
        defer {
            if bootstrapToken == token { isBootstrapping = false }
        }

        await apiClient.bootstrap()
        async let groupRequest = apiClient.forumGroups(userHash: userHash)
        async let timelineRequest = apiClient.timelines(userHash: userHash)
        async let noticeRequest = try? apiClient.notice()

        var loadedGroups: [ForumCategory]?
        var loadedTimelines: [Timeline]?
        var groupFailure: String?
        var timelineFailure: String?

        do {
            loadedGroups = try await groupRequest
        } catch is CancellationError {
            return
        } catch {
            groupFailure = error.localizedDescription
        }

        do {
            loadedTimelines = try await timelineRequest
        } catch is CancellationError {
            return
        } catch {
            timelineFailure = error.localizedDescription
        }

        let loadedNotice = await noticeRequest
        guard bootstrapToken == token, !Task.isCancelled else { return }

        if let loadedGroups { forumGroups = loadedGroups }
        if let loadedTimelines { timelines = loadedTimelines }
        notice = loadedNotice
        forumError = groupFailure
        timelineError = timelineFailure
    }

    func replaceSubscriptions(with ids: some Sequence<Int>) {
        subscribedThreadIDs = Set(ids.filter { $0 > 0 })
    }

    func lastPost(userHash: String) async throws -> LastPost {
        try await apiClient.lastPost(userHash: userHash)
    }

    func threadReadingPosition(for threadID: Int) -> ThreadReadingPosition? {
        threadReadingPositions[threadID]
    }

    func rememberThreadPosition(threadID: Int, page: Int, postID: Int?) {
        guard threadID > 0 else { return }
        let position = ThreadReadingPosition(
            page: max(page, 1),
            postID: postID
        )
        guard threadReadingPositions[threadID] != position else { return }
        threadReadingPositions[threadID] = position
    }
}
