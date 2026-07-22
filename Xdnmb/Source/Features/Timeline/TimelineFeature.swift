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

    func prepareForTimelineChange() {
        requestToken = UUID()
        threads = []
        page = 1
        isLoading = true
        errorMessage = nil
    }

    func loadPreview(page: Int = 1) {
        threads = PreviewFixtures.threads
        self.page = page
        isLoading = false
        errorMessage = nil
    }

    func load(timeline: Timeline, reset: Bool, userHash: String?) async {
        let targetPage = reset ? 1 : min(page + 1, timeline.maxPage)
        _ = await load(
            timeline: timeline,
            targetPage: targetPage,
            appending: !reset,
            userHash: userHash
        )
    }

    func jump(timeline: Timeline, to targetPage: Int, userHash: String?) async -> Bool {
        guard (1...timeline.maxPage).contains(targetPage) else { return false }
        return await load(
            timeline: timeline,
            targetPage: targetPage,
            appending: false,
            userHash: userHash
        )
    }

    private func load(
        timeline: Timeline,
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
            let result = try await APIService.shared.timelineThreads(
                id: timeline.id,
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

struct TimelineScreen: View {
    var chrome: MainFeedChromeModel? = nil
    var isChromeActive = true

    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var identity: IdentityStore
    @Environment(\.appRuntimeMode) private var runtimeMode
    @StateObject private var model = TimelineViewModel()
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
            } else if model.threads.isEmpty && model.isLoading {
                LoadingView(title: "正在加载时间线")
            } else if model.threads.isEmpty {
                RetryView(
                    title: model.errorMessage == nil
                        ? (model.page > 1 ? "第 \(model.page) 页没有内容" : "时间线还是空的")
                        : "加载失败",
                    message: model.errorMessage ?? "稍后再来看看新的讨论"
                ) {
                    guard let timeline = selectedTimeline else { return }
                    await load(timeline: timeline, reset: true)
                }
            } else {
                threadList
            }
        }
        .navigationTitle(selectedTimeline?.displayName ?? "X 岛")
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
            model.prepareForTimelineChange()
            await load(timeline: timeline, reset: true)
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
            canLoadMore: !runtimeMode.isPreview && (selectedTimeline.map { model.page < $0.maxPage } ?? false),
            scrollToTopRequest: scrollToTopRequest,
            scrollPosition: .constant(nil),
            onRefresh: {
                guard let timeline = selectedTimeline else { return }
                await load(timeline: timeline, reset: true)
            },
            onLoadMore: {
                guard let timeline = selectedTimeline else { return }
                await load(timeline: timeline, reset: false)
            },
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
                            guard let timeline = selectedTimeline else { return }
                            Task { await load(timeline: timeline, reset: false) }
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
        .navigationDestination(for: Int.self) { ThreadDetailScreen(threadID: $0) }
    }

    private func bootstrap() async {
        guard !runtimeMode.isPreview else { return }
        await app.bootstrap(userHash: identity.browsingUserHash)
    }

    private func load(timeline: Timeline, reset: Bool) async {
        if runtimeMode.isPreview {
            model.loadPreview()
        } else {
            await model.load(
                timeline: timeline,
                reset: reset,
                userHash: identity.browsingUserHash
            )
        }
    }

    private func jump(timeline: Timeline, to page: Int) async {
        let didLoad: Bool
        if runtimeMode.isPreview {
            model.loadPreview(page: page)
            didLoad = true
        } else {
            didLoad = await model.jump(
                timeline: timeline,
                to: page,
                userHash: identity.browsingUserHash
            )
        }
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
        model.prepareForTimelineChange()
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
