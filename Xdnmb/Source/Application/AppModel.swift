//
// AppModel.swift
// Author: Maru
//

import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var forumGroups: [ForumCategory] = []
    @Published private(set) var timelines: [Timeline] = []
    @Published private(set) var notice: SiteNotice?
    @Published private(set) var isBootstrapping = false
    @Published private(set) var forumError: String?
    @Published private(set) var timelineError: String?
    @Published var subscribedThreadIDs: Set<Int> = []

    private var bootstrapToken = UUID()

    var isConnected: Bool {
        !forumGroups.isEmpty || !timelines.isEmpty
    }

    func bootstrap() async {
        let token = UUID()
        bootstrapToken = token
        isBootstrapping = true
        defer {
            if bootstrapToken == token { isBootstrapping = false }
        }

        await APIService.shared.bootstrap()
        async let groupRequest = APIService.shared.forumGroups()
        async let timelineRequest = APIService.shared.timelines()
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
}
