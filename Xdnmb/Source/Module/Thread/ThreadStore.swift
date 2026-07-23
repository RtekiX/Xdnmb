//
// ThreadStore.swift
// Author: Maru
//

import Combine
import Foundation

@MainActor
final class ThreadStore: ObservableObject {
    let threadID: Int

    @Published private(set) var detail: ThreadDetail?
    @Published private(set) var page = 1
    @Published private(set) var onlyPO = false
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false
    @Published private(set) var errorMessage: String?

    private let apiClient: any XdnmbAPIClient
    private let runtimeMode: AppRuntimeMode
    private var activeUserHash: String?
    private var hasActiveIdentity = false
    private var requestToken = UUID()

    init(
        threadID: Int,
        apiClient: any XdnmbAPIClient,
        runtimeMode: AppRuntimeMode
    ) {
        self.threadID = threadID
        self.apiClient = apiClient
        self.runtimeMode = runtimeMode
    }

    func restore(page: Int) {
        guard !hasLoaded else { return }
        self.page = max(page, 1)
    }

    func activate(userHash: String?) async {
        if hasActiveIdentity, activeUserHash == userHash {
            if !hasLoaded, !isLoading { await load() }
            return
        }
        activeUserHash = userHash
        hasActiveIdentity = true
        hasLoaded = false
        await load()
    }

    func reload() async {
        guard hasActiveIdentity else { return }
        await load()
    }

    func toggleOnlyPO() async {
        onlyPO.toggle()
        page = 1
        hasLoaded = false
        await load()
    }

    func previousPage() async {
        guard page > 1, !isLoading else { return }
        page -= 1
        hasLoaded = false
        await load()
    }

    func nextPage() async {
        guard let detail, page < detail.maxPage, !isLoading else { return }
        page += 1
        hasLoaded = false
        await load()
    }

    func updateSubscription(
        currentlySubscribed: Bool,
        feedID: String,
        userHash: String
    ) async throws -> Bool {
        if runtimeMode.isPreview { return !currentlySubscribed }
        if currentlySubscribed {
            _ = try await apiClient.deleteFeed(
                feedID: feedID,
                threadID: threadID,
                userHash: userHash
            )
            return false
        }
        _ = try await apiClient.addFeed(
            feedID: feedID,
            threadID: threadID,
            userHash: userHash
        )
        return true
    }

    private func load() async {
        let token = UUID()
        requestToken = token
        isLoading = true
        defer {
            if requestToken == token { isLoading = false }
        }

        if runtimeMode.isPreview {
            detail = PreviewFixtures.threadDetail(id: threadID, onlyPO: onlyPO)
            page = 1
            hasLoaded = true
            errorMessage = nil
            return
        }

        do {
            let result = try await apiClient.thread(
                id: threadID,
                page: page,
                onlyPO: onlyPO,
                userHash: activeUserHash
            )
            guard requestToken == token, !Task.isCancelled else { return }
            detail = result
            page = min(max(page, 1), result.maxPage)
            hasLoaded = true
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            guard requestToken == token else { return }
            hasLoaded = true
            errorMessage = error.localizedDescription
        }
    }
}
