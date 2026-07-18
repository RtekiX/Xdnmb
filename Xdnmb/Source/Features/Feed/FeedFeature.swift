//
// FeedFeature.swift
// Author: Maru
//

import Combine
import SwiftUI

@MainActor
private final class FeedViewModel: ObservableObject {
    static let maximumPage = 1_000

    @Published private(set) var entries: [FeedEntry] = []
    @Published private(set) var page = 1
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?
    @Published private(set) var canLoadMore = false

    private var requestToken = UUID()
    private var loadedFeedID: String?

    func loadPreview(page: Int = 1, appending: Bool = false) {
        let previewEntries = page == 1 ? PreviewFixtures.feedEntries : []
        entries = appending ? entries.appendingUnique(previewEntries) : previewEntries
        self.page = page
        isLoading = false
        errorMessage = nil
        canLoadMore = false
    }

    func load(feedID: String, reset: Bool) async {
        loadedFeedID = feedID
        let targetPage = reset ? 1 : page + 1
        _ = await load(feedID: feedID, targetPage: targetPage, appending: !reset)
    }

    func loadIfNeeded(feedID: String) async {
        guard loadedFeedID != feedID else { return }
        loadedFeedID = feedID
        _ = await load(feedID: feedID, targetPage: 1, appending: false)
    }

    func jump(feedID: String, to targetPage: Int) async -> Bool {
        guard (1...Self.maximumPage).contains(targetPage) else { return false }
        return await load(feedID: feedID, targetPage: targetPage, appending: false)
    }

    private func load(feedID: String, targetPage: Int, appending: Bool) async -> Bool {
        if isLoading && appending { return false }
        let token = UUID()
        requestToken = token
        isLoading = true
        defer {
            if requestToken == token { isLoading = false }
        }

        do {
            let result = try await APIService.shared.feed(id: feedID, page: targetPage)
            guard requestToken == token, !Task.isCancelled else { return false }
            entries = appending ? entries.appendingUnique(result) : result
            page = targetPage
            canLoadMore = result.count >= 20
            errorMessage = nil
            return true
        } catch is CancellationError {
            return false
        } catch {
            guard requestToken == token else { return false }
            errorMessage = error.localizedDescription
            canLoadMore = false
            return false
        }
    }
}

struct FeedScreen: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var identity: IdentityStore
    @Environment(\.appRuntimeMode) private var runtimeMode
    @StateObject private var model = FeedViewModel()
    @State private var showingPageJump = false
    @State private var scrollToTopRequest = 0

    var body: some View {
        Group {
            if model.entries.isEmpty && model.isLoading {
                LoadingView(title: "正在加载订阅")
            } else if model.entries.isEmpty {
                ContentUnavailableView {
                    Label(
                        emptyStateTitle,
                        systemImage: model.errorMessage == nil ? "bookmark" : "wifi.exclamationmark"
                    )
                } description: {
                    Text(emptyStateMessage)
                } actions: {
                    Button(model.page > 1 ? "返回第 1 页" : "重新加载") {
                        Task { await jump(to: 1) }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                RefreshableInfiniteList(
                    items: model.entries,
                    isLoadingMore: model.isLoading,
                    canLoadMore: model.canLoadMore,
                    scrollToTopRequest: scrollToTopRequest,
                    scrollPosition: Binding(
                        get: { app.feedScrollThreadID },
                        set: {
                            guard app.feedScrollThreadID != $0 else { return }
                            app.feedScrollThreadID = $0
                        }
                    ),
                    onRefresh: { await load(reset: true) },
                    onLoadMore: { await load(reset: false) },
                    header: { EmptyView() },
                    row: { entry in
                        NavigationLink(value: entry.id) {
                            ThreadCard(thread: ForumThread(feedEntry: entry))
                        }
                        .buttonStyle(.plain)
                    },
                    footer: { feedFooter }
                )
                .background(AppTheme.groupedBackground)
                .navigationDestination(for: Int.self) { ThreadDetailScreen(threadID: $0) }
            }
        }
        .navigationTitle("订阅")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("第 \(model.page) 页") { showingPageJump = true }
                .disabled(model.isLoading && model.entries.isEmpty)
            }
        }
        .task(id: identity.feedID) { await loadIfNeeded() }
        .sheet(isPresented: $showingPageJump) {
            PageJumpSheet(
                currentPage: model.page,
                maximumPage: FeedViewModel.maximumPage,
                helpText: "Feed 接口不提供总页数；若目标页没有内容，可以返回第 1 页。"
            ) { page in
                Task { await jump(to: page) }
            }
        }
    }

    private var emptyStateTitle: String {
        if model.errorMessage != nil { return "订阅加载失败" }
        return model.page > 1 ? "第 \(model.page) 页没有内容" : "还没有订阅"
    }

    private var emptyStateMessage: String {
        model.errorMessage
        ?? (model.page > 1
            ? "这一页没有订阅内容，可以返回首页或跳转到其他页。"
            : "在帖子详情点击书签，就能在这里持续关注更新。")
    }

    @ViewBuilder
    private var feedFooter: some View {
        if let errorMessage = model.errorMessage {
            VStack(spacing: 8) {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("重试加载下一页") {
                    Task { await load(reset: false) }
                }
                .buttonStyle(.bordered)
            }
            .padding(.vertical, 12)
        } else if !model.canLoadMore {
            Text("已加载全部订阅")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.vertical, 12)
        }
    }

    private func load(reset: Bool) async {
        if runtimeMode.isPreview {
            model.loadPreview(page: reset ? 1 : model.page + 1, appending: !reset)
        } else {
            await model.load(feedID: identity.feedID, reset: reset)
        }
        if model.errorMessage == nil {
            app.replaceSubscriptions(with: model.entries.map(\.id))
        }
    }

    private func loadIfNeeded() async {
        if runtimeMode.isPreview {
            guard model.entries.isEmpty else { return }
            model.loadPreview()
        } else {
            await model.loadIfNeeded(feedID: identity.feedID)
        }
        if model.errorMessage == nil {
            app.replaceSubscriptions(with: model.entries.map(\.id))
        }
    }

    private func jump(to page: Int) async {
        let didLoad: Bool
        if runtimeMode.isPreview {
            model.loadPreview(page: page)
            didLoad = true
        } else {
            didLoad = await model.jump(feedID: identity.feedID, to: page)
        }
        guard didLoad else { return }
        app.replaceSubscriptions(with: model.entries.map(\.id))
        app.feedScrollThreadID = model.entries.first?.id
        scrollToTopRequest += 1
    }
}
