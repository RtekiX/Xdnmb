//
// BoardDirectoryFeature.swift
// Author: Maru
//

import SwiftUI

struct MainFeedScreen: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var preferences: BoardPreferencesStore
    @EnvironmentObject private var appNavigationChrome: AppNavigationChromeModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @StateObject private var chrome = HomeFeedChromeModel()
    @StateObject private var navigationState = HomeNavigationState()
    @State private var selectedSourceID = "timeline"
    @State private var directThreadID: Int?
    @State private var showingBoardManagement = false

    private let sourceRailHeight: CGFloat = 48
    private let sourceContentMargin: CGFloat = 54

    private var allForums: [Forum] {
        app.forumGroups.flatMap(\.visibleForums).deduplicatedForums()
    }

    private var residentForums: [Forum] {
        preferences.visibleForums(from: allForums)
    }

    var body: some View {
        feedWithSources
        .sheet(isPresented: $showingBoardManagement) {
            NavigationStack {
                BoardManagementScreen(forums: allForums, isPresentedModally: true)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .navigationDestination(isPresented: Binding(
            get: { directThreadID != nil },
            set: { if !$0 { directThreadID = nil } }
        )) {
            if let directThreadID {
                ThreadDetailScreen(threadID: directThreadID)
            }
        }
        .task(id: allForums.map(\.id)) {
            preferences.reconcile(with: allForums)
            ensureValidSelection()
        }
        .onChange(of: residentForums.map(\.id)) {
            ensureValidSelection()
        }
        .onChange(of: voiceOverEnabled) {
            if voiceOverEnabled {
                navigationState.showSources()
            }
        }
        .onChange(of: navigationState.hidesBottomBar) {
            appNavigationChrome.setBottomBarVisible(!navigationState.hidesBottomBar)
        }
        .onAppear {
            appNavigationChrome.setBottomBarVisible(!navigationState.hidesBottomBar)
        }
        .onDisappear {
            appNavigationChrome.showBottomBar()
        }
    }

    private var feedWithSources: some View {
        ZStack(alignment: .top) {
            feedPager
            sourceChrome
                .padding(.horizontal, 12)
                .padding(.top, 6)
                .zIndex(1)
        }
    }

    private var feedPager: some View {
        TabView(selection: selectedSourceBinding) {
            TimelineScreen(
                chrome: chrome,
                isChromeActive: selectedSourceID == "timeline",
                topContentMargin: sourceContentMargin,
                onScrollOffsetChange: handleScrollOffset,
                onScrollPhaseChange: handleScrollPhase,
                onOpenThread: { directThreadID = $0 }
            )
            .tag("timeline")

            ForEach(residentForums) { forum in
                let id = sourceID(for: forum)
                ForumScreen(
                    forum: forum,
                    chrome: chrome,
                    isChromeActive: selectedSourceID == id,
                    topContentMargin: sourceContentMargin,
                    onScrollOffsetChange: handleScrollOffset,
                    onScrollPhaseChange: handleScrollPhase
                )
                .tag(id)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }

    private var sourceChrome: some View {
        ZStack(alignment: .top) {
            HomeSourceBar(
                forums: residentForums,
                selectedSourceID: selectedSourceBinding
            ) {
                sourceMenu(showTitle: false)
            } primaryAction: {
                primaryActionButton
            }
            .frame(height: sourceRailHeight)
            .offset(
                y: -sourceContentMargin * (1 - navigationState.revealProgress)
            )
            .opacity(navigationState.revealProgress)
            .allowsHitTesting(navigationState.acceptsSourceInteraction)
            .accessibilityHidden(!navigationState.acceptsSourceInteraction)

            HomeCompactCommandBar {
                sourceMenu(showTitle: true)
            } primaryAction: {
                primaryActionButton
            }
            .opacity(1 - navigationState.revealProgress)
            .scaleEffect(0.94 + (0.06 * (1 - navigationState.revealProgress)))
            .allowsHitTesting(!navigationState.acceptsSourceInteraction)
            .accessibilityHidden(navigationState.acceptsSourceInteraction)
        }
    }

    private func sourceMenu(showTitle: Bool) -> some View {
        Menu {
            if !navigationState.isExpanded {
                Button {
                    withAnimation(navigationAnimation) {
                        navigationState.showSources()
                    }
                } label: {
                    Label("显示版块导航", systemImage: "rectangle.expand.vertical")
                }
            }

            if chrome.leadingEnabled {
                Button {
                    chrome.performLeadingAction()
                } label: {
                    Label(chrome.leadingTitle, systemImage: chrome.leadingSymbol)
                }
            }

            if chrome.pageEnabled {
                Button {
                    chrome.openPagePicker()
                } label: {
                    Label(
                        "跳转页面 · 当前第 \(chrome.page) 页",
                        systemImage: "doc.text.magnifyingglass"
                    )
                }
            }

            Divider()

            Button {
                showingBoardManagement = true
            } label: {
                Label("管理常驻版块", systemImage: "slider.horizontal.3")
            }
        } label: {
            if showTitle {
                HStack(spacing: 5) {
                    Text(currentSourceTitle)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.semibold))
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .frame(height: 40)
            } else {
                Image(systemName: "ellipsis")
                    .font(.body.weight(.semibold))
                    .frame(width: 40, height: 40)
                    .contentShape(.circle)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("当前来源，\(currentSourceTitle)")
        .accessibilityHint("打开来源与页面操作")
    }

    @ViewBuilder
    private var primaryActionButton: some View {
        let button = Button {
            chrome.performPrimaryAction()
        } label: {
            Image(systemName: chrome.primarySymbol)
                .frame(width: 40, height: 40)
                .contentShape(.circle)
        }
        .disabled(!chrome.primaryEnabled)
        .opacity(chrome.primaryEnabled ? 1 : 0)
        .accessibilityLabel(chrome.primaryTitle)

        if #available(iOS 26.0, *) {
            button
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .glassEffect(
                    .regular.tint(AppTheme.accent).interactive(),
                    in: .circle
                )
        } else {
            button
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(AppTheme.accent, in: .circle)
        }
    }

    private var currentSourceTitle: String {
        if selectedSourceID == "timeline" {
            return chrome.navigationTitle
        }
        return residentForums.first {
            sourceID(for: $0) == selectedSourceID
        }?.displayName ?? chrome.navigationTitle
    }

    private var selectedSourceBinding: Binding<String> {
        Binding(
            get: { selectedSourceID },
            set: { newValue in
                guard selectedSourceID != newValue else { return }
                selectedSourceID = newValue
                withAnimation(navigationAnimation) {
                    navigationState.beginSourceTransition()
                }
            }
        )
    }

    private var navigationAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.12)
            : .snappy(duration: 0.2)
    }

    private func handleScrollOffset(_ offset: CGFloat) {
        navigationState.recordScrollOffset(
            offset,
            allowsAutomaticCollapse: !voiceOverEnabled
        )
    }

    private func handleScrollPhase(_ isScrolling: Bool) {
        guard !isScrolling, !voiceOverEnabled else { return }
        withAnimation(navigationAnimation) {
            navigationState.settle()
        }
    }

    private func sourceID(for forum: Forum) -> String {
        "forum-\(forum.id)"
    }

    private func ensureValidSelection() {
        guard selectedSourceID != "timeline" else { return }
        let validIDs = Set(residentForums.map(sourceID))
        if !validIDs.contains(selectedSourceID) {
            selectedSourceID = "timeline"
            navigationState.beginSourceTransition()
        }
    }
}

private struct HomeSourceBar<MenuContent: View, PrimaryAction: View>: View {
    let forums: [Forum]
    @Binding var selectedSourceID: String
    let menu: () -> MenuContent
    let primaryAction: () -> PrimaryAction

    init(
        forums: [Forum],
        selectedSourceID: Binding<String>,
        @ViewBuilder menu: @escaping () -> MenuContent,
        @ViewBuilder primaryAction: @escaping () -> PrimaryAction
    ) {
        self.forums = forums
        _selectedSourceID = selectedSourceID
        self.menu = menu
        self.primaryAction = primaryAction
    }

    @ViewBuilder
    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 10) {
                barContent
                    .glassEffect(.regular, in: .capsule)
            }
        } else {
            barContent
                .background(.ultraThinMaterial, in: .capsule)
                .overlay {
                    Capsule()
                        .stroke(.primary.opacity(0.08), lineWidth: 0.5)
                }
        }
    }

    private var barContent: some View {
        HStack(spacing: 4) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        sourceButton(title: "综合线", sourceID: "timeline")
                            .id("timeline")

                        ForEach(forums) { forum in
                            let sourceID = "forum-\(forum.id)"
                            sourceButton(title: forum.displayName, sourceID: sourceID)
                                .id(sourceID)
                        }
                    }
                    .padding(.leading, 4)
                }
                .mask {
                    HStack(spacing: 0) {
                        Rectangle()
                        LinearGradient(
                            colors: [.white, .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: 18)
                    }
                }
                .onChange(of: selectedSourceID) {
                    withAnimation(.snappy) {
                        proxy.scrollTo(selectedSourceID, anchor: .center)
                    }
                }
            }

            Divider()
                .frame(height: 24)

            menu()

            primaryAction()
            .padding(.trailing, 4)
        }
        .padding(.vertical, 4)
        .frame(height: 48)
    }

    @ViewBuilder
    private func sourceButton(title: String, sourceID: String) -> some View {
        let button = Button {
            withAnimation(.snappy) {
                selectedSourceID = sourceID
            }
        } label: {
            Text(title)
                .font(.subheadline.weight(selectedSourceID == sourceID ? .semibold : .regular))
                .lineLimit(1)
                .padding(.horizontal, 14)
                .frame(height: 40)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityValue(selectedSourceID == sourceID ? "已选择" : "未选择")

        if #available(iOS 26.0, *) {
            if selectedSourceID == sourceID {
                button
                    .foregroundStyle(.white)
                    .glassEffect(
                        .regular.tint(AppTheme.accent).interactive(),
                        in: .capsule
                    )
            } else {
                button.foregroundStyle(.primary)
            }
        } else if selectedSourceID == sourceID {
            button
                .foregroundStyle(.white)
                .background(AppTheme.accent, in: .capsule)
        } else {
            button.foregroundStyle(.primary)
        }
    }
}

private struct HomeCompactCommandBar<MenuContent: View, PrimaryAction: View>: View {
    let menu: () -> MenuContent
    let primaryAction: () -> PrimaryAction

    init(
        @ViewBuilder menu: @escaping () -> MenuContent,
        @ViewBuilder primaryAction: @escaping () -> PrimaryAction
    ) {
        self.menu = menu
        self.primaryAction = primaryAction
    }

    var body: some View {
        HStack(spacing: 8) {
            glassSurface {
                menu()
            }
            Spacer(minLength: 12)
            primaryAction()
        }
        .frame(height: 48)
    }

    @ViewBuilder
    private func glassSurface<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        if #available(iOS 26.0, *) {
            content()
                .glassEffect(.regular, in: .capsule)
        } else {
            content()
                .background(.ultraThinMaterial, in: .capsule)
                .overlay {
                    Capsule()
                        .stroke(.primary.opacity(0.08), lineWidth: 0.5)
                }
        }
    }
}

struct BoardManagementScreen: View {
    let forums: [Forum]
    var isPresentedModally = false

    @EnvironmentObject private var preferences: BoardPreferencesStore
    @Environment(\.dismiss) private var dismiss
    @State private var editMode: EditMode = .active
    @State private var searchText = ""

    private var residentForums: [Forum] {
        preferences.visibleForums(from: forums)
    }

    private var availableForums: [Forum] {
        let hiddenForums = preferences.hiddenForums(from: forums)
        guard !searchText.isEmpty else { return hiddenForums }
        return hiddenForums.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            Section {
                ForEach(residentForums) { forum in
                    HStack(spacing: 12) {
                        BoardRow(forum: forum)
                        Spacer()
                        Button("移除", systemImage: "minus.circle") {
                            preferences.setVisible(false, forumID: forum.id)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .onMove { offsets, destination in
                    preferences.moveVisibleForums(
                        from: offsets,
                        to: destination,
                        forums: forums
                    )
                }
            } header: {
                Text("首页常驻")
            } footer: {
                Text("拖动右侧排序控件调整首页来源顺序；综合线始终固定在最前。")
            }

            if !availableForums.isEmpty {
                Section("添加版块") {
                    ForEach(availableForums) { forum in
                        HStack {
                            BoardRow(forum: forum)
                            Spacer()
                            Button("添加", systemImage: "plus.circle") {
                                preferences.setVisible(true, forumID: forum.id)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            } else if !searchText.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .navigationTitle("常驻版块")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "搜索待添加版块")
        .environment(\.editMode, $editMode)
        .toolbar {
            if isPresentedModally {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .fontWeight(.semibold)
                }
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
        }
        .onAppear {
            preferences.reconcile(with: forums)
            editMode = .active
        }
    }
}

private extension Array where Element == Forum {
    func deduplicatedForums() -> [Forum] {
        var ids = Set<Int>()
        return filter { ids.insert($0.id).inserted }
    }
}
