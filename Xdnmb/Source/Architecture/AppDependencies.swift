//
// AppDependencies.swift
// Author: Maru
//

import Combine

@MainActor
final class AppSessionStore: ObservableObject {
    private let apiClient: any XdnmbAPIClient
    private let runtimeMode: AppRuntimeMode

    private let timelineSession: ThreadListStore
    private let feedSession: ThreadListStore
    private var forumSessions: [Int: ThreadListStore] = [:]
    private var threadSessions: [Int: ThreadStore] = [:]
    private var threadSessionOrder: [Int] = []

    private let maximumThreadSessionCount = 32

    init(apiClient: any XdnmbAPIClient, runtimeMode: AppRuntimeMode) {
        self.apiClient = apiClient
        self.runtimeMode = runtimeMode
        timelineSession = ThreadListStore(apiClient: apiClient, runtimeMode: runtimeMode)
        feedSession = ThreadListStore(apiClient: apiClient, runtimeMode: runtimeMode)
    }

    func timelineStore() -> ThreadListStore {
        timelineSession
    }

    func forumStore(for forumID: Int) -> ThreadListStore {
        if let store = forumSessions[forumID] { return store }
        let store = ThreadListStore(apiClient: apiClient, runtimeMode: runtimeMode)
        forumSessions[forumID] = store
        return store
    }

    func feedStore() -> ThreadListStore {
        feedSession
    }

    func makeComposerStore() -> ComposerStore {
        ComposerStore(apiClient: apiClient, runtimeMode: runtimeMode)
    }

    func threadStore(for threadID: Int) -> ThreadStore {
        if let store = threadSessions[threadID] {
            markThreadSessionAsRecent(threadID)
            return store
        }
        let store = ThreadStore(
            threadID: threadID,
            apiClient: apiClient,
            runtimeMode: runtimeMode
        )
        threadSessions[threadID] = store
        markThreadSessionAsRecent(threadID)
        discardOldThreadSessionsIfNeeded()
        return store
    }

    private func markThreadSessionAsRecent(_ threadID: Int) {
        threadSessionOrder.removeAll { $0 == threadID }
        threadSessionOrder.append(threadID)
    }

    private func discardOldThreadSessionsIfNeeded() {
        while threadSessionOrder.count > maximumThreadSessionCount {
            let discardedID = threadSessionOrder.removeFirst()
            threadSessions[discardedID] = nil
        }
    }
}
