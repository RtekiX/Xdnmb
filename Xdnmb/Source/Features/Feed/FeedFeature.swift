//
// FeedFeature.swift
// Author: Maru
//

import Combine
import SwiftUI

@MainActor
private final class FeedViewModel: ObservableObject {
    @Published private(set) var entries: [FeedEntry] = []
    @Published private(set) var page = 1
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?
    @Published private(set) var canLoadMore = false

    private var requestToken = UUID()

    func load(feedID: String, reset: Bool) async {
        if isLoading && !reset { return }
        let token = UUID()
        requestToken = token
        isLoading = true
        defer {
            if requestToken == token { isLoading = false }
        }
        let targetPage = reset ? 1 : page + 1

        do {
            let result = try await APIService.shared.feed(id: feedID, page: targetPage)
            guard requestToken == token, !Task.isCancelled else { return }
            entries = reset ? result : entries.appendingUnique(result)
            if reset || !result.isEmpty { page = targetPage }
            canLoadMore = result.count >= 20
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            guard requestToken == token else { return }
            errorMessage = error.localizedDescription
            canLoadMore = false
        }
    }
}

struct FeedScreen: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var identity: IdentityStore
    @StateObject private var model = FeedViewModel()

    var body: some View {
        Group {
            if model.entries.isEmpty && model.isLoading {
                LoadingView(title: "正在加载订阅")
            } else if model.entries.isEmpty {
                ContentUnavailableView {
                    Label(
                        model.errorMessage == nil ? "还没有订阅" : "订阅加载失败",
                        systemImage: model.errorMessage == nil ? "bookmark" : "wifi.exclamationmark"
                    )
                } description: {
                    Text(model.errorMessage ?? "在帖子详情点击书签，就能在这里持续关注更新。")
                } actions: {
                    Button("重新加载") {
                        Task { await load(reset: true) }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(model.entries) { entry in
                            NavigationLink(value: entry.id) {
                                ThreadCard(thread: ForumThread(feedEntry: entry))
                            }
                            .buttonStyle(.plain)
                        }
                        if model.isLoading { ProgressView().padding() }
                        if model.canLoadMore && !model.isLoading {
                            Button("加载更多") {
                                Task { await load(reset: false) }
                            }
                            .buttonStyle(.bordered)
                            .padding(.vertical, 8)
                        }
                    }
                    .padding(16)
                }
                .background(AppTheme.groupedBackground)
                .navigationDestination(for: Int.self) { ThreadDetailScreen(threadID: $0) }
                .refreshable { await load(reset: true) }
            }
        }
        .navigationTitle("订阅")
        .task(id: identity.feedID) { await load(reset: true) }
    }

    private func load(reset: Bool) async {
        await model.load(feedID: identity.feedID, reset: reset)
        if model.errorMessage == nil {
            app.replaceSubscriptions(with: model.entries.map(\.id))
        }
    }
}
