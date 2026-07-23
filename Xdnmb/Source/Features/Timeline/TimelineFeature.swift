//
// TimelineFeature.swift
// Author: Maru
//

import SwiftUI

struct TimelineScreen: View {
    var chrome: MainFeedChromeModel? = nil
    var isChromeActive = true

    @EnvironmentObject private var sessions: AppSessionStore

    var body: some View {
        TimelineScreenContent(
            model: sessions.timelineStore(),
            chrome: chrome,
            isChromeActive: isChromeActive
        )
    }
}

private struct TimelineScreenContent: View {
    @ObservedObject var model: ThreadListStore
    var chrome: MainFeedChromeModel? = nil
    var isChromeActive = true

    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var identity: IdentityStore
    @Environment(\.appRuntimeMode) private var runtimeMode
    @State private var selectedTimelineID: Int?
    @State private var showingThreadJump = false
    @State private var showingPageJump = false
    @State private var showingTimelinePicker = false
    @State private var directThreadID: Int?
    @State private var scrollToTopRequest = 0

    private var selectedTimeline: Timeline? {
        app.timelines.first { $0.id == selectedTimelineID } ?? app.timelines.first
    }

    private var loadTaskID: String {
        "\(selectedTimeline?.id ?? 0)-\(identity.browsingCookieID?.uuidString ?? "anonymous")"
    }

    var body: some View {
        Group {
            if app.isBootstrapping && app.timelines.isEmpty {
                LoadingView(title: "正在连接 X 岛")
            } else if app.timelines.isEmpty, let error = app.timelineError {
                RetryView(title: "暂时无法连接", message: error) { await bootstrap() }
            } else if model.threads.isEmpty && model.isInitialLoading {
                LoadingView(title: "正在加载时间线")
            } else if model.threads.isEmpty {
                RetryView(
                    title: model.errorMessage == nil
                        ? (model.page > 1 ? "第 \(model.page) 页没有内容" : "时间线还是空的")
                        : "加载失败",
                    message: model.errorMessage ?? "稍后再来看看新的讨论"
                ) {
                    await model.refresh()
                }
            } else {
                threadList
            }
        }
        .navigationTitle(selectedTimeline?.displayName ?? "X 岛")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if chrome == nil {
                ToolbarItem(placement: .topBarLeading) {
                    timelineSelectorMenu
                        .labelStyle(.iconOnly)
                        .disabled(app.timelines.isEmpty)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("第 \(model.page) 页") { showingPageJump = true }
                        .disabled(selectedTimeline == nil || model.isLoading)
                    Button { showingThreadJump = true } label: {
                        Label("串号直达", systemImage: "number")
                    }
                }
            }
        }
        .task(id: loadTaskID) {
            guard let timeline = selectedTimeline else { return }
            selectedTimelineID = timeline.id
            await model.activate(
                source: .timeline(id: timeline.id, maximumPage: timeline.maxPage),
                userHash: identity.browsingUserHash
            )
        }
        .onAppear { updateChrome() }
        .onChange(of: isChromeActive) { updateChrome() }
        .onChange(of: model.page) { updateChrome() }
        .onChange(of: model.isLoading) { updateChrome() }
        .onChange(of: selectedTimeline?.id) { updateChrome() }
        .sheet(isPresented: $showingThreadJump) {
            ThreadJumpSheet { directThreadID = $0 }
        }
        .sheet(isPresented: $showingPageJump) {
            if let timeline = selectedTimeline {
                PageJumpSheet(currentPage: model.page, maximumPage: timeline.maxPage) { page in
                    Task { await jump(timeline: timeline, to: page) }
                }
            }
        }
        .confirmationDialog(
            "切换时间线",
            isPresented: $showingTimelinePicker,
            titleVisibility: .visible
        ) {
            ForEach(app.timelines) { timeline in
                Button {
                    selectTimeline(timeline)
                } label: {
                    if timeline.id == selectedTimeline?.id {
                        Label(timeline.displayName, systemImage: "checkmark")
                    } else {
                        Text(timeline.displayName)
                    }
                }
            }
        } message: {
            Text("切换后将从所选时间线的第 1 页开始加载。")
        }
        .navigationDestination(isPresented: Binding(
            get: { directThreadID != nil },
            set: { if !$0 { directThreadID = nil } }
        )) {
            if let id = directThreadID { ThreadDetailScreen(threadID: id) }
        }
    }

    private var threadList: some View {
        RefreshableInfiniteList(
            items: model.threads,
            isLoadingMore: model.isLoading,
            canLoadMore: model.canLoadMore,
            scrollToTopRequest: scrollToTopRequest,
            onRefresh: { await model.refresh() },
            onLoadMore: { await model.loadMore() },
            header: {
                if let notice = app.notice, notice.enable, notice.content.nilIfBlank != nil {
                    NavigationLink {
                        NoticeDetailScreen(
                            title: "站点公告",
                            content: notice.content,
                            date: notice.date,
                            source: "站点公告"
                        )
                    } label: {
                        PinnedNoticeThreadCard(
                            title: "站点公告",
                            content: notice.content,
                            date: notice.date
                        )
                    }
                    .buttonStyle(.plain)
                }
                if let timeline = selectedTimeline, let text = timeline.notice.htmlPlainText.nilIfBlank {
                    NavigationLink {
                        NoticeDetailScreen(
                            title: "\(timeline.displayName)公告",
                            content: text,
                            source: timeline.displayName
                        )
                    } label: {
                        PinnedNoticeThreadCard(
                            title: "\(timeline.displayName)公告",
                            content: text,
                            symbol: "info.circle.fill"
                        )
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
                } else if let timeline = selectedTimeline, model.page >= timeline.maxPage {
                    Text("已加载全部讨论")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 12)
                }
            }
        )
        .background(AppTheme.groupedBackground)
    }

    private func bootstrap() async {
        guard !runtimeMode.isPreview else { return }
        await app.bootstrap(userHash: identity.browsingUserHash)
    }

    private func jump(timeline: Timeline, to page: Int) async {
        let didLoad = await model.jump(to: page)
        guard didLoad else { return }
        scrollToTopRequest += 1
    }

    private var timelineSelectorMenu: some View {
        Menu {
            ForEach(app.timelines) { timeline in
                Button {
                    selectTimeline(timeline)
                } label: {
                    if selectedTimeline?.id == timeline.id {
                        Label(timeline.displayName, systemImage: "checkmark")
                    } else {
                        Text(timeline.displayName)
                    }
                }
            }
        } label: {
            Label(
                selectedTimeline?.displayName ?? "切换时间线",
                systemImage: "line.3.horizontal.decrease.circle"
            )
        }
    }

    private func selectTimeline(_ timeline: Timeline) {
        guard timeline.id != selectedTimeline?.id else { return }
        selectedTimelineID = timeline.id
        scrollToTopRequest += 1
        updateChrome()
    }

    private func updateChrome() {
        guard isChromeActive, let chrome else { return }
        chrome.configure(
            page: model.page,
            pageEnabled: selectedTimeline != nil && !model.isLoading,
            leadingTitle: "切换时间线",
            leadingSymbol: "line.3.horizontal.decrease.circle",
            primaryTitle: "串号直达",
            primarySymbol: "number",
            onLeadingTap: { showingTimelinePicker = true },
            onPageTap: { showingPageJump = true },
            onPrimaryTap: { showingThreadJump = true }
        )
    }
}
