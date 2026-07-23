//
// ForumFeature.swift
// Author: Maru
//

import SwiftUI

struct ForumScreen: View {
    let forum: Forum
    var chrome: MainFeedChromeModel? = nil
    var isChromeActive = true

    @EnvironmentObject private var sessions: AppSessionStore

    var body: some View {
        ForumScreenContent(
            forum: forum,
            model: sessions.forumStore(for: forum.id),
            chrome: chrome,
            isChromeActive: isChromeActive
        )
    }
}

private struct ForumScreenContent: View {
    let forum: Forum
    @ObservedObject var model: ThreadListStore
    var chrome: MainFeedChromeModel? = nil
    var isChromeActive = true

    @EnvironmentObject private var identity: IdentityStore
    @State private var showingComposer = false
    @State private var showingPageJump = false
    @State private var showingNotice = false
    @State private var scrollToTopRequest = 0

    private var loadTaskID: String {
        "\(forum.id)-\(identity.browsingCookieID?.uuidString ?? "anonymous")"
    }

    var body: some View {
        Group {
            if model.threads.isEmpty && model.isInitialLoading {
                LoadingView(title: "正在加载\(forum.displayName)")
            } else if model.threads.isEmpty {
                RetryView(
                    title: model.errorMessage == nil
                        ? (model.page > 1 ? "第 \(model.page) 页没有内容" : "这里还没有帖子")
                        : "加载失败",
                    message: model.errorMessage ?? "成为第一个发起讨论的人吧"
                ) {
                    await model.refresh()
                }
            } else {
                RefreshableInfiniteList(
                    items: model.threads,
                    isLoadingMore: model.isLoading,
                    canLoadMore: model.canLoadMore,
                    scrollToTopRequest: scrollToTopRequest,
                    onRefresh: { await model.refresh() },
                    onLoadMore: { await model.loadMore() },
                    header: {
                        if forum.message.htmlPlainText.nilIfBlank != nil {
                            NavigationLink {
                                ForumNoticeScreen(forum: forum)
                            } label: {
                                ForumNoticeThreadCard(forum: forum)
                            }
                            .buttonStyle(.plain)
                        }
                    },
                    row: { thread in
                        NavigationLink {
                            ThreadDetailScreen(threadID: thread.id)
                        } label: {
                            ThreadCard(thread: thread)
                        }
                        .buttonStyle(.plain)
                    },
                    footer: {
                        if let errorMessage = model.errorMessage {
                            VStack(spacing: 8) {
                                Text(errorMessage)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                Button("重试加载下一页") {
                                    Task { await model.retry() }
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(.vertical, 12)
                        } else if model.page >= forum.maxPage {
                            Text("已加载全部讨论")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 12)
                        }
                    }
                )
                .background(AppTheme.groupedBackground)
            }
        }
        .navigationTitle(forum.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showingNotice) {
            ForumNoticeScreen(forum: forum)
        }
        .toolbar {
            if chrome == nil {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("第 \(model.page) 页") { showingPageJump = true }
                        .disabled(model.isLoading)
                    Button { showingComposer = true } label: {
                        Label("发新串", systemImage: "square.and.pencil")
                    }
                }
            }
        }
        .task(id: loadTaskID) {
            await model.activate(
                source: .forum(id: forum.id, maximumPage: forum.maxPage),
                userHash: identity.browsingUserHash
            )
        }
        .onAppear { updateChrome() }
        .onChange(of: isChromeActive) { updateChrome() }
        .onChange(of: model.page) { updateChrome() }
        .onChange(of: model.isLoading) { updateChrome() }
        .sheet(isPresented: $showingComposer) {
            ComposerScreen(mode: .thread(forum), identity: identity) {
                await model.refresh()
            }
        }
        .sheet(isPresented: $showingPageJump) {
            PageJumpSheet(currentPage: model.page, maximumPage: forum.maxPage) { page in
                Task { await jump(to: page) }
            }
        }
    }

    private func jump(to page: Int) async {
        let didLoad = await model.jump(to: page)
        guard didLoad else { return }
        scrollToTopRequest += 1
    }

    private func updateChrome() {
        guard isChromeActive, let chrome else { return }
        chrome.configure(
            page: model.page,
            pageEnabled: !model.isLoading,
            leadingTitle: "版块公告",
            leadingSymbol: "pin.fill",
            leadingEnabled: forum.message.htmlPlainText.nilIfBlank != nil,
            primaryTitle: "发新串",
            primarySymbol: "square.and.pencil",
            onLeadingTap: { showingNotice = true },
            onPageTap: { showingPageJump = true },
            onPrimaryTap: { showingComposer = true }
        )
    }
}

private struct ForumNoticeThreadCard: View {
    let forum: Forum

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "pin.fill")
                    .foregroundStyle(AppTheme.accent)
                Text("置顶")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.accent)
                Spacer()
                Text("版块公告")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("\(forum.displayName)版块公告")
                .font(.headline)
            Text(forum.message.htmlPlainText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            HStack {
                Label("查看完整公告", systemImage: "doc.text")
                Spacer()
                Image(systemName: "chevron.right")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(AppTheme.elevated, in: .rect(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppTheme.accent.opacity(0.28), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("打开版块公告详情")
    }
}

private struct ForumNoticeScreen: View {
    let forum: Forum

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Label("置顶版块公告", systemImage: "pin.fill")
                        .font(.headline)
                        .foregroundStyle(AppTheme.accent)
                    Text(forum.message.htmlPlainText)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(18)
                .background(AppTheme.elevated, in: .rect(cornerRadius: 18))

                VStack(alignment: .leading, spacing: 12) {
                    Text("版块信息").font(.headline)
                    LabeledContent("版块名称", value: forum.displayName)
                    if let threadCount = forum.threadCount {
                        LabeledContent("主题数", value: String(threadCount))
                    }
                    if let postCount = forum.postCount {
                        LabeledContent("帖子数", value: String(postCount))
                    }
                    if let interval = forum.interval, interval > 0 {
                        LabeledContent("发帖间隔", value: "\(interval) 秒")
                    }
                    if forum.safeMode == true {
                        LabeledContent("安全模式", value: "已启用")
                    }
                }
                .padding(18)
                .background(AppTheme.elevated, in: .rect(cornerRadius: 18))
            }
            .padding(16)
        }
        .background(AppTheme.groupedBackground)
        .navigationTitle("版块公告")
        .navigationBarTitleDisplayMode(.inline)
    }
}
