//
// FeedFeature.swift
// Author: Maru
//

import SwiftUI

struct FeedScreen: View {
    @EnvironmentObject private var sessions: AppSessionStore

    var body: some View {
        FeedScreenContent(model: sessions.feedStore())
    }
}

private struct FeedScreenContent: View {
    @ObservedObject var model: ThreadListStore

    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var identity: IdentityStore
    @State private var showingPageJump = false
    @State private var scrollToTopRequest = 0

    var body: some View {
        Group {
            if model.threads.isEmpty && model.isInitialLoading {
                LoadingView(title: "正在加载订阅")
            } else if model.threads.isEmpty {
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
                    items: model.threads,
                    isLoadingMore: model.isLoading,
                    canLoadMore: model.canLoadMore,
                    scrollToTopRequest: scrollToTopRequest,
                    onRefresh: { await refresh() },
                    onLoadMore: { await loadMore() },
                    header: { EmptyView() },
                    row: { thread in
                        NavigationLink {
                            ThreadDetailScreen(threadID: thread.id)
                        } label: {
                            ThreadCard(thread: thread)
                        }
                        .buttonStyle(.plain)
                    },
                    footer: { feedFooter }
                )
                .background(AppTheme.groupedBackground)
            }
        }
        .navigationTitle("订阅")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Menu {
                    Button {
                        showingPageJump = true
                    } label: {
                        Label(
                            "跳转页面 · 当前第 \(model.page) 页",
                            systemImage: "doc.text.magnifyingglass"
                        )
                    }
                    .disabled(model.isLoading && model.threads.isEmpty)
                } label: {
                    HStack(spacing: 5) {
                        Text("订阅")
                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.semibold))
                    }
                    .font(.headline)
                }
                .accessibilityHint("打开订阅页面操作")
            }
        }
        .task(id: "\(identity.feedID)-\(identity.browsingCookieID?.uuidString ?? "anonymous")") {
            await model.activate(
                source: .feed(id: identity.feedID),
                userHash: identity.browsingUserHash
            )
            updateSubscriptions()
        }
        .sheet(isPresented: $showingPageJump) {
            PageJumpSheet(
                currentPage: model.page,
                maximumPage: 1_000,
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
                    Task {
                        await model.retry()
                        updateSubscriptions()
                    }
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

    private func refresh() async {
        await model.refresh()
        updateSubscriptions()
    }

    private func loadMore() async {
        await model.loadMore()
        updateSubscriptions()
    }

    private func jump(to page: Int) async {
        let didLoad = await model.jump(to: page)
        guard didLoad else { return }
        updateSubscriptions()
        scrollToTopRequest += 1
    }

    private func updateSubscriptions() {
        guard model.errorMessage == nil else { return }
        app.replaceSubscriptions(with: model.threads.map(\.id))
    }
}
