//
// ThreadFeature.swift
// Author: Maru
//

import Combine
import SwiftUI

@MainActor
private final class ThreadViewModel: ObservableObject {
    let threadID: Int

    @Published private(set) var detail: ThreadDetail?
    @Published private(set) var page = 1
    @Published private(set) var onlyPO = false
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?

    private var requestToken = UUID()

    init(threadID: Int) {
        self.threadID = threadID
    }

    func load() async {
        let token = UUID()
        requestToken = token
        isLoading = true
        defer {
            if requestToken == token { isLoading = false }
        }
        do {
            let result = try await APIService.shared.thread(id: threadID, page: page, onlyPO: onlyPO)
            guard requestToken == token, !Task.isCancelled else { return }
            detail = result
            page = min(max(page, 1), result.maxPage)
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            guard requestToken == token else { return }
            errorMessage = error.localizedDescription
        }
    }

    func toggleOnlyPO() async {
        onlyPO.toggle()
        page = 1
        detail = nil
        await load()
    }

    func previousPage() async {
        guard page > 1, !isLoading else { return }
        page -= 1
        await load()
    }

    func nextPage() async {
        guard let detail, page < detail.maxPage, !isLoading else { return }
        page += 1
        await load()
    }
}

struct ThreadDetailScreen: View {
    let threadID: Int

    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var identity: IdentityStore
    @StateObject private var model: ThreadViewModel
    @State private var actionMessage: String?
    @State private var showingReply = false
    @State private var subscriptionBusy = false

    init(threadID: Int) {
        self.threadID = threadID
        _model = StateObject(wrappedValue: ThreadViewModel(threadID: threadID))
    }

    var body: some View {
        Group {
            if let detail = model.detail {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            PostCard(post: detail.post, isOriginalPoster: true)
                                .id("root")
                            if detail.replies.isEmpty {
                                ContentUnavailableView("暂无回复", systemImage: "bubble.left.and.bubble.right")
                                    .padding(.vertical, 32)
                            } else {
                                ForEach(Array(detail.replies.enumerated()), id: \.offset) { _, post in
                                    PostCard(
                                        post: post,
                                        isOriginalPoster: !post.userHash.isEmpty && post.userHash == detail.post.userHash
                                    )
                                }
                            }
                            if detail.maxPage > 1 {
                                PageControl(
                                    page: model.page,
                                    maxPage: detail.maxPage,
                                    isLoading: model.isLoading,
                                    onPrevious: {
                                        await model.previousPage()
                                        withAnimation { proxy.scrollTo("root", anchor: .top) }
                                    },
                                    onNext: {
                                        await model.nextPage()
                                        withAnimation { proxy.scrollTo("root", anchor: .top) }
                                    }
                                )
                            }
                        }
                        .padding(16)
                    }
                    .background(AppTheme.groupedBackground)
                    .refreshable { await model.load() }
                }
            } else if model.isLoading {
                LoadingView(title: "正在展开帖子")
            } else {
                RetryView(
                    title: "帖子加载失败",
                    message: model.errorMessage ?? "请稍后重试"
                ) {
                    await model.load()
                }
            }
        }
        .navigationTitle("No.\(threadID)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    Task { await model.toggleOnlyPO() }
                } label: {
                    Label(
                        "只看 PO",
                        systemImage: model.onlyPO
                            ? "person.crop.circle.fill.badge.checkmark"
                            : "person.crop.circle"
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
        .safeAreaInset(edge: .bottom) {
            Button { showingReply = true } label: {
                Label(
                    identity.hasIdentity ? "回复这个帖子" : "导入饼干后回复",
                    systemImage: "arrowshape.turn.up.left"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)
        }
        .task { await model.load() }
        .sheet(isPresented: $showingReply) {
            ComposerScreen(mode: .reply(threadID), identity: identity) { await model.load() }
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
        guard let hash = identity.userHash.nilIfBlank else {
            actionMessage = APIError.missingIdentity.localizedDescription
            return
        }
        guard !subscriptionBusy else { return }
        subscriptionBusy = true
        defer { subscriptionBusy = false }

        do {
            if app.subscribedThreadIDs.contains(threadID) {
                _ = try await APIService.shared.deleteFeed(
                    feedID: identity.feedID,
                    threadID: threadID,
                    userHash: hash
                )
                app.subscribedThreadIDs.remove(threadID)
                actionMessage = "已取消订阅"
            } else {
                _ = try await APIService.shared.addFeed(
                    feedID: identity.feedID,
                    threadID: threadID,
                    userHash: hash
                )
                app.subscribedThreadIDs.insert(threadID)
                actionMessage = "已加入订阅"
            }
        } catch is CancellationError {
            return
        } catch {
            actionMessage = error.localizedDescription
        }
    }
}
