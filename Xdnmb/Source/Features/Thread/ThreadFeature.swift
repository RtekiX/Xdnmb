//
// ThreadFeature.swift
// Author: Maru
//

import SwiftUI

struct ThreadDetailScreen: View {
    let threadID: Int

    @EnvironmentObject private var sessions: AppSessionStore

    var body: some View {
        ThreadDetailScreenContent(
            threadID: threadID,
            model: sessions.threadStore(for: threadID)
        )
    }
}

private struct ThreadDetailScreenContent: View {
    let threadID: Int
    @ObservedObject var model: ThreadStore

    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var identity: IdentityStore
    @EnvironmentObject private var bottomAccessory: AppBottomAccessoryModel
    @State private var actionMessage: String?
    @State private var showingReply = false
    @State private var subscriptionBusy = false
    @State private var didRestoreReadingPosition = false

    var body: some View {
        Group {
            if let detail = model.detail {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            PostCard(post: detail.post, isOriginalPoster: true)
                                .id(detail.post.id)
                            if detail.replies.isEmpty {
                                ContentUnavailableView("暂无回复", systemImage: "bubble.left.and.bubble.right")
                                    .padding(.vertical, 32)
                            } else {
                                ForEach(detail.replies, id: \.id) { post in
                                    PostCard(
                                        post: post,
                                        isOriginalPoster: !post.userHash.isEmpty && post.userHash == detail.post.userHash
                                    )
                                    .id(post.id)
                                }
                            }
                            if detail.maxPage > 1 {
                                PageControl(
                                    page: model.page,
                                    maxPage: detail.maxPage,
                                    isLoading: model.isLoading,
                                    onPrevious: {
                                        await model.previousPage()
                                        remember(postID: model.detail?.post.id)
                                        withAnimation { proxy.scrollTo(model.detail?.post.id, anchor: .top) }
                                    },
                                    onNext: {
                                        await model.nextPage()
                                        remember(postID: model.detail?.post.id)
                                        withAnimation { proxy.scrollTo(model.detail?.post.id, anchor: .top) }
                                    }
                                )
                            }
                        }
                        .scrollTargetLayout()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .scrollPosition(id: threadScrollPosition, anchor: .center)
                    .xdnmbSoftScrollEdgeEffect()
                    .background(AppTheme.groupedBackground)
                    .refreshable { await load() }
                }
            } else if model.isLoading || !model.hasLoaded {
                LoadingView(title: "正在展开帖子")
            } else {
                RetryView(
                    title: "帖子加载失败",
                    message: model.errorMessage ?? "请稍后重试"
                ) {
                    await load()
                }
            }
        }
        .navigationTitle("No.\(threadID)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    Task { await toggleOnlyPO() }
                } label: {
                    Label(
                        "只看 PO",
                        systemImage: model.onlyPO
                            ? "line.3.horizontal.decrease.circle.fill"
                            : "line.3.horizontal.decrease.circle"
                    )
                }
                .disabled(model.isLoading)
                .accessibilityValue(model.onlyPO ? "已开启" : "已关闭")

                Button { Task { await toggleSubscription() } } label: {
                    if subscriptionBusy {
                        ProgressView()
                    } else {
                        Label(
                            app.subscribedThreadIDs.contains(threadID) ? "取消订阅" : "订阅",
                            systemImage: app.subscribedThreadIDs.contains(threadID) ? "bookmark.fill" : "bookmark"
                        )
                    }
                }
                .disabled(subscriptionBusy)
            }
        }
        .task(id: identity.browsingCookieID) { await load() }
        .onAppear { configureBottomAccessory() }
        .onChange(of: identity.hasIdentity) { configureBottomAccessory() }
        .onDisappear {
            bottomAccessory.clear(ownerID: accessoryOwnerID)
        }
        .sheet(isPresented: $showingReply) {
            ComposerScreen(mode: .reply(threadID), identity: identity) { await model.reload() }
        }
        .alert("提示", isPresented: Binding(
            get: { actionMessage != nil },
            set: { if !$0 { actionMessage = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(actionMessage ?? "")
        }
    }

    private func toggleSubscription() async {
        guard let hash = identity.browsingUserHash else {
            actionMessage = APIError.missingIdentity.localizedDescription
            return
        }
        guard !subscriptionBusy else { return }
        subscriptionBusy = true
        defer { subscriptionBusy = false }

        do {
            let wasSubscribed = app.subscribedThreadIDs.contains(threadID)
            let isSubscribed = try await model.updateSubscription(
                currentlySubscribed: wasSubscribed,
                feedID: identity.feedID,
                userHash: hash
            )
            if isSubscribed {
                app.subscribedThreadIDs.insert(threadID)
                actionMessage = "已加入订阅"
            } else {
                app.subscribedThreadIDs.remove(threadID)
                actionMessage = "已取消订阅"
            }
        } catch is CancellationError {
            return
        } catch {
            actionMessage = error.localizedDescription
        }
    }

    private func load() async {
        if !didRestoreReadingPosition {
            if let position = app.threadReadingPosition(for: threadID) {
                model.restore(page: position.page)
            }
            didRestoreReadingPosition = true
        }
        await model.activate(userHash: identity.browsingUserHash)
        remember(postID: threadScrollPosition.wrappedValue ?? model.detail?.post.id)
    }

    private func toggleOnlyPO() async {
        await model.toggleOnlyPO()
        remember(postID: model.detail?.post.id)
    }

    private var threadScrollPosition: Binding<Int?> {
        Binding(
            get: { app.threadReadingPosition(for: threadID)?.postID },
            set: { remember(postID: $0) }
        )
    }

    private func remember(postID: Int?) {
        app.rememberThreadPosition(threadID: threadID, page: model.page, postID: postID)
    }

    private var replyTitle: String {
        identity.hasIdentity ? "回复这个帖子" : "导入饼干后回复"
    }

    private var accessoryOwnerID: String {
        "thread-\(threadID)"
    }

    private func configureBottomAccessory() {
        bottomAccessory.configure(
            ownerID: accessoryOwnerID,
            title: replyTitle,
            symbol: "arrowshape.turn.up.left",
            action: { showingReply = true }
        )
    }
}
