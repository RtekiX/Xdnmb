//
// ForumFeature.swift
// Author: Maru
//

import Combine
import SwiftUI

@MainActor
private final class ForumViewModel: ObservableObject {
    @Published private(set) var threads: [ForumThread] = []
    @Published private(set) var page = 1
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?

    private var requestToken = UUID()

    func loadPreview(page: Int = 1) {
        threads = PreviewFixtures.threads
        self.page = page
        isLoading = false
        errorMessage = nil
    }

    func load(forum: Forum, reset: Bool, userHash: String?) async {
        let targetPage = reset ? 1 : min(page + 1, forum.maxPage)
        _ = await load(forum: forum, targetPage: targetPage, appending: !reset, userHash: userHash)
    }

    func jump(forum: Forum, to targetPage: Int, userHash: String?) async -> Bool {
        guard (1...forum.maxPage).contains(targetPage) else { return false }
        return await load(forum: forum, targetPage: targetPage, appending: false, userHash: userHash)
    }

    private func load(
        forum: Forum,
        targetPage: Int,
        appending: Bool,
        userHash: String?
    ) async -> Bool {
        if isLoading && appending { return false }
        let token = UUID()
        requestToken = token
        isLoading = true
        defer {
            if requestToken == token { isLoading = false }
        }
        do {
            let result = try await APIService.shared.forumThreads(
                id: forum.id,
                page: targetPage,
                userHash: userHash
            )
            guard requestToken == token, !Task.isCancelled else { return false }
            threads = appending ? threads.appendingUnique(result) : result
            page = targetPage
            errorMessage = nil
            return true
        } catch is CancellationError {
            return false
        } catch {
            guard requestToken == token else { return false }
            errorMessage = error.localizedDescription
            return false
        }
    }
}

struct ForumScreen: View {
    let forum: Forum
    var chrome: MainFeedChromeModel? = nil
    var isChromeActive = true

    @EnvironmentObject private var identity: IdentityStore
    @Environment(\.appRuntimeMode) private var runtimeMode
    @StateObject private var model = ForumViewModel()
    @State private var showingComposer = false
    @State private var showingPageJump = false
    @State private var showingNotice = false
    @State private var scrollToTopRequest = 0

    var body: some View {
        Group {
            if model.threads.isEmpty && model.isLoading {
                LoadingView(title: "正在加载\(forum.displayName)")
            } else if model.threads.isEmpty {
                RetryView(
                    title: model.errorMessage == nil
                        ? (model.page > 1 ? "第 \(model.page) 页没有内容" : "这里还没有帖子")
                        : "加载失败",
                    message: model.errorMessage ?? "成为第一个发起讨论的人吧"
                ) {
                    await load(reset: true)
                }
            } else {
                RefreshableInfiniteList(
                    items: model.threads,
                    isLoadingMore: model.isLoading,
                    canLoadMore: !runtimeMode.isPreview && model.page < forum.maxPage,
                    scrollToTopRequest: scrollToTopRequest,
                    scrollPosition: .constant(nil),
                    onRefresh: { await load(reset: true) },
                    onLoadMore: { await load(reset: false) },
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
                        NavigationLink(value: thread.id) { ThreadCard(thread: thread) }
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
                                    Task { await load(reset: false) }
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
        .navigationDestination(for: Int.self) { ThreadDetailScreen(threadID: $0) }
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
        .task(id: "\(forum.id)-\(identity.browsingCookieID?.uuidString ?? "anonymous")") {
            await load(reset: true)
        }
        .onAppear { updateChrome() }
        .onChange(of: isChromeActive) { updateChrome() }
        .onChange(of: model.page) { updateChrome() }
        .onChange(of: model.isLoading) { updateChrome() }
        .sheet(isPresented: $showingComposer) {
            ComposerScreen(mode: .thread(forum), identity: identity) {
                await load(reset: true)
            }
        }
        .sheet(isPresented: $showingPageJump) {
            PageJumpSheet(currentPage: model.page, maximumPage: forum.maxPage) { page in
                Task { await jump(to: page) }
            }
        }
    }

    private func load(reset: Bool) async {
        if runtimeMode.isPreview {
            model.loadPreview()
        } else {
            await model.load(forum: forum, reset: reset, userHash: identity.browsingUserHash)
        }
    }

    private func jump(to page: Int) async {
        let didLoad: Bool
        if runtimeMode.isPreview {
            model.loadPreview(page: page)
            didLoad = true
        } else {
            didLoad = await model.jump(
                forum: forum,
                to: page,
                userHash: identity.browsingUserHash
            )
        }
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
