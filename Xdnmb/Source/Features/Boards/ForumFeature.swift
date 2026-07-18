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

    func load(forum: Forum, reset: Bool) async {
        if isLoading && !reset { return }
        let token = UUID()
        requestToken = token
        isLoading = true
        defer {
            if requestToken == token { isLoading = false }
        }
        let targetPage = reset ? 1 : min(page + 1, forum.maxPage)

        do {
            let result = try await APIService.shared.forumThreads(id: forum.id, page: targetPage)
            guard requestToken == token, !Task.isCancelled else { return }
            threads = reset ? result : threads.appendingUnique(result)
            if reset || !result.isEmpty { page = targetPage }
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            guard requestToken == token else { return }
            errorMessage = error.localizedDescription
        }
    }
}

struct ForumScreen: View {
    let forum: Forum

    @EnvironmentObject private var identity: IdentityStore
    @StateObject private var model = ForumViewModel()
    @State private var showingComposer = false

    var body: some View {
        Group {
            if model.threads.isEmpty && model.isLoading {
                LoadingView(title: "正在加载\(forum.displayName)")
            } else if model.threads.isEmpty {
                RetryView(
                    title: model.errorMessage == nil ? "这里还没有帖子" : "加载失败",
                    message: model.errorMessage ?? "成为第一个发起讨论的人吧"
                ) {
                    await model.load(forum: forum, reset: true)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ContextBanner(icon: "text.bubble", text: forum.summary)
                        ForEach(model.threads) { thread in
                            NavigationLink(value: thread.id) { ThreadCard(thread: thread) }
                                .buttonStyle(.plain)
                        }
                        if model.isLoading { ProgressView().padding() }
                        if model.page < forum.maxPage && !model.isLoading {
                            Button("加载更多") {
                                Task { await model.load(forum: forum, reset: false) }
                            }
                            .buttonStyle(.bordered)
                            .padding()
                        }
                    }
                    .padding(16)
                }
                .background(AppTheme.groupedBackground)
                .refreshable { await model.load(forum: forum, reset: true) }
            }
        }
        .navigationTitle(forum.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Int.self) { ThreadDetailScreen(threadID: $0) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingComposer = true } label: {
                    Label("发新串", systemImage: "square.and.pencil")
                }
            }
        }
        .task(id: forum.id) { await model.load(forum: forum, reset: true) }
        .sheet(isPresented: $showingComposer) {
            ComposerScreen(mode: .thread(forum), identity: identity) {
                await model.load(forum: forum, reset: true)
            }
        }
    }
}
