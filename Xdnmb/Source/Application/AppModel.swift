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
    @Published var feedScrollThreadID: Int?
    @Published private(set) var threadReadingPositions: [Int: ThreadReadingPosition] = [:]

    private var bootstrapToken = UUID()

    init(
        forumGroups: [ForumCategory] = [],
        timelines: [Timeline] = [],
        notice: SiteNotice? = nil,
        subscribedThreadIDs: Set<Int> = []
    ) {
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

        await APIService.shared.bootstrap()
        async let groupRequest = APIService.shared.forumGroups(userHash: userHash)
        async let timelineRequest = APIService.shared.timelines(userHash: userHash)
        async let noticeRequest = try? APIService.shared.notice()

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
