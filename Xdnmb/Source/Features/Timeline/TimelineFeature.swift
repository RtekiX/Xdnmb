//
// TimelineFeature.swift
// Author: Maru
//

import Combine
import SwiftUI

@MainActor
private final class TimelineViewModel: ObservableObject {
    @Published private(set) var threads: [ForumThread] = []
    @Published private(set) var page = 1
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?

    private var requestToken = UUID()

    func load(timeline: Timeline, reset: Bool) async {
        if isLoading && !reset { return }
        let token = UUID()
        requestToken = token
        isLoading = true
        defer {
            if requestToken == token { isLoading = false }
        }
        let targetPage = reset ? 1 : min(page + 1, timeline.maxPage)

        do {
            let result = try await APIService.shared.timelineThreads(id: timeline.id, page: targetPage)
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

struct TimelineScreen: View {
    @EnvironmentObject private var app: AppModel
    @StateObject private var model = TimelineViewModel()
    @State private var selectedTimelineID: Int?
    @State private var showingJump = false
    @State private var directThreadID: Int?

    private var selectedTimeline: Timeline? {
        app.timelines.first { $0.id == selectedTimelineID } ?? app.timelines.first
    }

    var body: some View {
        Group {
            if app.isBootstrapping && app.timelines.isEmpty {
                LoadingView(title: "正在连接 X 岛")
            } else if app.timelines.isEmpty, let error = app.timelineError {
                RetryView(title: "暂时无法连接", message: error) { await app.bootstrap() }
            } else if model.threads.isEmpty && model.isLoading {
                LoadingView(title: "正在加载时间线")
            } else if model.threads.isEmpty {
                RetryView(
                    title: model.errorMessage == nil ? "时间线还是空的" : "加载失败",
                    message: model.errorMessage ?? "稍后再来看看新的讨论"
                ) {
                    guard let timeline = selectedTimeline else { return }
                    await model.load(timeline: timeline, reset: true)
                }
            } else {
                threadList
            }
        }
        .navigationTitle(selectedTimeline?.displayName ?? "X 岛")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    ForEach(app.timelines) { timeline in
                        Button {
                            selectedTimelineID = timeline.id
                        } label: {
                            if selectedTimeline?.id == timeline.id {
                                Label(timeline.displayName, systemImage: "checkmark")
                            } else {
                                Text(timeline.displayName)
                            }
                        }
                    }
                } label: {
                    Label("切换时间线", systemImage: "line.3.horizontal.decrease.circle")
                }
                .disabled(app.timelines.isEmpty)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingJump = true } label: {
                    Label("串号直达", systemImage: "number")
                }
            }
        }
        .task(id: selectedTimeline?.id) {
            guard let timeline = selectedTimeline else { return }
            selectedTimelineID = timeline.id
            await model.load(timeline: timeline, reset: true)
        }
        .sheet(isPresented: $showingJump) {
            ThreadJumpSheet { directThreadID = $0 }
        }
        .navigationDestination(isPresented: Binding(
            get: { directThreadID != nil },
            set: { if !$0 { directThreadID = nil } }
        )) {
            if let id = directThreadID { ThreadDetailScreen(threadID: id) }
        }
    }

    private var threadList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if let notice = app.notice, notice.enable, notice.content.nilIfBlank != nil {
                    NoticeCard(notice: notice)
                }
                if let timeline = selectedTimeline, let text = timeline.notice.htmlPlainText.nilIfBlank {
                    ContextBanner(icon: "info.circle", text: text)
                }
                ForEach(model.threads) { thread in
                    NavigationLink(value: thread.id) { ThreadCard(thread: thread) }
                        .buttonStyle(.plain)
                }
                if model.isLoading { ProgressView().padding() }
                if let timeline = selectedTimeline,
                   model.page < timeline.maxPage,
                   !model.isLoading {
                    Button("加载更多") {
                        Task { await model.load(timeline: timeline, reset: false) }
                    }
                    .buttonStyle(.bordered)
                    .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(AppTheme.groupedBackground)
        .refreshable {
            guard let timeline = selectedTimeline else { return }
            await model.load(timeline: timeline, reset: true)
        }
        .navigationDestination(for: Int.self) { ThreadDetailScreen(threadID: $0) }
    }
}
