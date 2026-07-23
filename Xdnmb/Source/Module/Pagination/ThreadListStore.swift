//
// ThreadListStore.swift
// Author: Maru
//

import Combine
import Foundation

enum ThreadListSource: Hashable, Sendable {
    case timeline(id: Int, maximumPage: Int)
    case forum(id: Int, maximumPage: Int)
    case feed(id: String)

    var maximumPage: Int {
        switch self {
        case .timeline(_, let maximumPage), .forum(_, let maximumPage):
            return max(maximumPage, 1)
        case .feed:
            return 1_000
        }
    }
}

private struct ThreadListRequest: Equatable {
    let source: ThreadListSource
    let userHash: String?
}

@MainActor
final class ThreadListStore: ObservableObject {
    @Published private(set) var threads: [ForumThread] = []
    @Published private(set) var page = 1
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false
    @Published private(set) var canLoadMore = false
    @Published private(set) var errorMessage: String?

    private let apiClient: any XdnmbAPIClient
    private let runtimeMode: AppRuntimeMode
    private var activeRequest: ThreadListRequest?
    private var requestToken = UUID()
    private var retryPage: Int?
    private var retryAppends = false

    init(apiClient: any XdnmbAPIClient, runtimeMode: AppRuntimeMode) {
        self.apiClient = apiClient
        self.runtimeMode = runtimeMode
    }

    var isInitialLoading: Bool {
        !hasLoaded || (threads.isEmpty && isLoading)
    }

    func activate(source: ThreadListSource, userHash: String?) async {
        let request = ThreadListRequest(source: source, userHash: userHash)
        if activeRequest == request {
            if !hasLoaded, !isLoading {
                await performLoad(page: 1, appending: false, request: request)
            }
            return
        }

        requestToken = UUID()
        activeRequest = request
        threads = []
        page = 1
        hasLoaded = false
        canLoadMore = false
        errorMessage = nil
        retryPage = nil
        await performLoad(page: 1, appending: false, request: request)
    }

    func refresh() async {
        guard let activeRequest else { return }
        await performLoad(page: 1, appending: false, request: activeRequest)
    }

    func loadMore() async {
        guard let activeRequest, canLoadMore, !isLoading else { return }
        await performLoad(page: page + 1, appending: true, request: activeRequest)
    }

    func retry() async {
        guard let activeRequest else { return }
        let targetPage = retryPage ?? (threads.isEmpty ? 1 : page + 1)
        await performLoad(
            page: targetPage,
            appending: retryPage == nil ? !threads.isEmpty : retryAppends,
            request: activeRequest
        )
    }

    @discardableResult
    func jump(to targetPage: Int) async -> Bool {
        guard let activeRequest,
              (1...activeRequest.source.maximumPage).contains(targetPage) else { return false }
        return await performLoad(page: targetPage, appending: false, request: activeRequest)
    }

    @discardableResult
    private func performLoad(
        page targetPage: Int,
        appending: Bool,
        request: ThreadListRequest
    ) async -> Bool {
        guard activeRequest == request else { return false }
        if isLoading && appending { return false }

        let token = UUID()
        requestToken = token
        isLoading = true
        defer {
            if requestToken == token { isLoading = false }
        }

        do {
            let result = try await fetch(request: request, page: targetPage)
            guard requestToken == token,
                  activeRequest == request,
                  !Task.isCancelled else { return false }

            let merged = appending ? threads.appendingUnique(result) : result
            let addedItems = merged.count > threads.count
            threads = merged
            page = targetPage
            hasLoaded = true
            canLoadMore = nextPageIsAvailable(
                request: request,
                resultCount: result.count,
                addedItems: !appending || addedItems,
                page: targetPage
            )
            errorMessage = nil
            retryPage = nil
            return true
        } catch is CancellationError {
            return false
        } catch {
            guard requestToken == token, activeRequest == request else { return false }
            hasLoaded = true
            canLoadMore = false
            errorMessage = error.localizedDescription
            retryPage = targetPage
            retryAppends = appending
            return false
        }
    }

    private func fetch(request: ThreadListRequest, page: Int) async throws -> [ForumThread] {
        if runtimeMode.isPreview {
            guard page == 1 else { return [] }
            switch request.source {
            case .feed:
                return PreviewFixtures.feedEntries.map(ForumThread.init(feedEntry:))
            case .timeline, .forum:
                return PreviewFixtures.threads
            }
        }

        switch request.source {
        case .timeline(let id, _):
            return try await apiClient.timelineThreads(id: id, page: page, userHash: request.userHash)
        case .forum(let id, _):
            return try await apiClient.forumThreads(id: id, page: page, userHash: request.userHash)
        case .feed(let id):
            let entries = try await apiClient.feed(id: id, page: page, userHash: request.userHash)
            return entries.map(ForumThread.init(feedEntry:))
        }
    }

    private func nextPageIsAvailable(
        request: ThreadListRequest,
        resultCount: Int,
        addedItems: Bool,
        page: Int
    ) -> Bool {
        guard !runtimeMode.isPreview,
              page < request.source.maximumPage,
              resultCount > 0,
              addedItems else { return false }
        switch request.source {
        case .feed:
            return resultCount >= 20
        case .timeline, .forum:
            return true
        }
    }
}
