//
// BoardDirectoryFeature.swift
// Author: Maru
//

import SwiftUI
import UniformTypeIdentifiers

struct MainFeedScreen: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var preferences: BoardPreferencesStore
    @StateObject private var chrome = MainFeedChromeModel()
    @State private var selectedSourceID = "timeline"
    @State private var draggedForumID: Int?
    @State private var showsSourceTabs = true

    private var allForums: [Forum] {
        app.forumGroups.flatMap(\.visibleForums).deduplicatedForums()
    }

    private var visibleForums: [Forum] {
        preferences.visibleForums(from: allForums)
    }

    var body: some View {
        VStack(spacing: 0) {
            MainFeedTabBar(
                forums: visibleForums,
                allForums: allForums,
                selectedSourceID: $selectedSourceID,
                draggedForumID: $draggedForumID
            )
            .frame(height: showsSourceTabs ? 55 : 0, alignment: .top)
            .opacity(showsSourceTabs ? 1 : 0)
            .clipped()
            .allowsHitTesting(showsSourceTabs)
            Divider()
                .frame(height: showsSourceTabs ? 1 : 0)
                .opacity(showsSourceTabs ? 1 : 0)
            TabView(selection: $selectedSourceID) {
                TimelineScreen(chrome: chrome, isChromeActive: selectedSourceID == "timeline")
                    .tag("timeline")
                ForEach(visibleForums) { forum in
                    ForumScreen(
                        forum: forum,
                        chrome: chrome,
                        isChromeActive: selectedSourceID == "forum-\(forum.id)"
                    )
                        .tag("forum-\(forum.id)")
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .animation(.snappy(duration: 0.22), value: showsSourceTabs)
        .environment(\.mainFeedNavigationVisibilityHandler) { shouldShow in
            guard showsSourceTabs != shouldShow else { return }
            withAnimation(.snappy(duration: 0.22)) {
                showsSourceTabs = shouldShow
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { chrome.performLeadingAction() } label: {
                    Image(systemName: chrome.leadingSymbol)
                        .frame(width: 28)
                }
                .disabled(!chrome.leadingEnabled)
                .opacity(chrome.leadingEnabled ? 1 : 0)
                .accessibilityLabel(chrome.leadingTitle)
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { chrome.openPagePicker() } label: {
                    Text("第 \(chrome.page) 页")
                        .monospacedDigit()
                        .frame(width: 62)
                }
                .disabled(!chrome.pageEnabled)
                Button { chrome.performPrimaryAction() } label: {
                    Image(systemName: chrome.primarySymbol)
                        .frame(width: 28)
                }
                .disabled(!chrome.primaryEnabled)
                .accessibilityLabel(chrome.primaryTitle)
            }
        }
        .task(id: allForums.map(\.id)) {
            preferences.reconcile(with: allForums)
        }
        .onChange(of: visibleForums.map(\.id)) {
            guard selectedSourceID != "timeline" else { return }
            let validIDs = Set(visibleForums.map { "forum-\($0.id)" })
            if !validIDs.contains(selectedSourceID) {
                selectedSourceID = "timeline"
            }
        }
        .onChange(of: selectedSourceID) {
            showsSourceTabs = true
        }
    }
}

private struct MainFeedTabBar: View {
    let forums: [Forum]
    let allForums: [Forum]
    @Binding var selectedSourceID: String
    @Binding var draggedForumID: Int?

    @EnvironmentObject private var preferences: BoardPreferencesStore

    var body: some View {
        HStack(spacing: 4) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        sourceButton(title: "综合线", sourceID: "timeline")
                            .id("timeline")
                        ForEach(forums) { forum in
                            sourceButton(title: forum.displayName, sourceID: "forum-\(forum.id)")
                                .id("forum-\(forum.id)")
                                .onDrag {
                                    draggedForumID = forum.id
                                    return NSItemProvider(object: String(forum.id) as NSString)
                                }
                                .onDrop(
                                    of: [UTType.text],
                                    delegate: BoardTabDropDelegate(
                                        destinationID: forum.id,
                                        draggedForumID: $draggedForumID,
                                        preferences: preferences
                                    )
                                )
                                .accessibilityHint("长按拖动可调整版块顺序")
                        }
                    }
                    .padding(.leading, 12)
                    .padding(.vertical, 8)
                }
                .onChange(of: selectedSourceID) {
                    withAnimation { proxy.scrollTo(selectedSourceID, anchor: .center) }
                }
            }
            NavigationLink {
                BoardManagementScreen(forums: allForums)
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .frame(width: 38, height: 38)
                    .background(.quaternary, in: .circle)
            }
            .accessibilityLabel("管理版块")
            .padding(.trailing, 10)
        }
        .background(.bar)
    }

    private func sourceButton(title: String, sourceID: String) -> some View {
        Button {
            withAnimation(.snappy) { selectedSourceID = sourceID }
        } label: {
            Text(title)
                .font(.subheadline.weight(selectedSourceID == sourceID ? .semibold : .regular))
                .foregroundStyle(selectedSourceID == sourceID ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    selectedSourceID == sourceID ? AppTheme.accent : Color.clear,
                    in: .capsule
                )
        }
        .buttonStyle(.plain)
    }
}

struct BoardDirectoryScreen: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var preferences: BoardPreferencesStore
    @Environment(\.appRuntimeMode) private var runtimeMode
    @State private var selectedForumID: Int?
    @State private var draggedForumID: Int?

    private var allForums: [Forum] {
        app.forumGroups.flatMap(\.visibleForums).deduplicatedForums()
    }

    private var visibleForums: [Forum] {
        preferences.visibleForums(from: allForums)
    }

    private var selectedForum: Forum? {
        visibleForums.first { $0.id == selectedForumID } ?? visibleForums.first
    }

    var body: some View {
        Group {
            if app.isBootstrapping && allForums.isEmpty {
                LoadingView(title: "正在加载版块")
            } else if allForums.isEmpty, let error = app.forumError {
                RetryView(title: "版块加载失败", message: error) { await refresh() }
            } else if visibleForums.isEmpty {
                ContentUnavailableView {
                    Label("没有显示的版块", systemImage: "rectangle.stack.badge.minus")
                } description: {
                    Text("请在版块管理中选择至少一个要展示的版块。")
                } actions: {
                    NavigationLink("打开版块管理") {
                        BoardManagementScreen(forums: allForums)
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                VStack(spacing: 0) {
                    BoardTabBar(
                        forums: visibleForums,
                        selectedForumID: Binding(
                            get: { selectedForum?.id },
                            set: { selectedForumID = $0 }
                        ),
                        draggedForumID: $draggedForumID
                    )
                    Divider()
                    TabView(selection: Binding(
                        get: { selectedForum?.id ?? visibleForums[0].id },
                        set: { selectedForumID = $0 }
                    )) {
                        ForEach(visibleForums) { forum in
                            ForumScreen(forum: forum)
                                .tag(forum.id)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
        }
        .navigationTitle(selectedForum?.displayName ?? "版块")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink {
                    BoardManagementScreen(forums: allForums)
                } label: {
                    Label("管理版块", systemImage: "slider.horizontal.3")
                }
                .disabled(allForums.isEmpty)
            }
        }
        .task(id: allForums.map(\.id)) {
            preferences.reconcile(with: allForums)
            ensureValidSelection()
        }
        .onChange(of: visibleForums.map(\.id)) {
            ensureValidSelection()
        }
    }

    private func ensureValidSelection() {
        guard !visibleForums.isEmpty else {
            selectedForumID = nil
            return
        }
        if !visibleForums.contains(where: { $0.id == selectedForumID }) {
            selectedForumID = visibleForums[0].id
        }
    }

    private func refresh() async {
        guard !runtimeMode.isPreview else { return }
        await app.bootstrap()
    }
}

private struct BoardTabBar: View {
    let forums: [Forum]
    @Binding var selectedForumID: Int?
    @Binding var draggedForumID: Int?

    @EnvironmentObject private var preferences: BoardPreferencesStore

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(forums) { forum in
                        Button {
                            withAnimation(.snappy) { selectedForumID = forum.id }
                        } label: {
                            Text(forum.displayName)
                                .font(.subheadline.weight(selectedForumID == forum.id ? .semibold : .regular))
                                .foregroundStyle(selectedForumID == forum.id ? .white : .primary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    selectedForumID == forum.id ? AppTheme.accent : Color.clear,
                                    in: .capsule
                                )
                        }
                        .buttonStyle(.plain)
                        .id(forum.id)
                        .onDrag {
                            draggedForumID = forum.id
                            return NSItemProvider(object: String(forum.id) as NSString)
                        }
                        .onDrop(
                            of: [UTType.text],
                            delegate: BoardTabDropDelegate(
                                destinationID: forum.id,
                                draggedForumID: $draggedForumID,
                                preferences: preferences
                            )
                        )
                        .accessibilityHint("长按拖动可调整版块顺序")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .onChange(of: selectedForumID) {
                guard let selectedForumID else { return }
                withAnimation { proxy.scrollTo(selectedForumID, anchor: .center) }
            }
        }
        .background(.bar)
    }
}

private struct BoardTabDropDelegate: DropDelegate {
    let destinationID: Int
    @Binding var draggedForumID: Int?
    let preferences: BoardPreferencesStore

    func dropEntered(info: DropInfo) {
        guard let draggedForumID, draggedForumID != destinationID else { return }
        withAnimation(.snappy) {
            preferences.move(forumID: draggedForumID, before: destinationID)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedForumID = nil
        return true
    }
}

struct BoardManagementScreen: View {
    let forums: [Forum]

    @EnvironmentObject private var preferences: BoardPreferencesStore

    private var visibleForums: [Forum] { preferences.visibleForums(from: forums) }
    private var hiddenForums: [Forum] { preferences.hiddenForums(from: forums) }

    var body: some View {
        List {
            Section {
                ForEach(visibleForums) { forum in
                    HStack(spacing: 12) {
                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(.tertiary)
                        BoardRow(forum: forum)
                        Spacer()
                        Button("隐藏", systemImage: "eye.slash") {
                            preferences.setVisible(false, forumID: forum.id)
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                    }
                }
                .onMove { offsets, destination in
                    preferences.moveVisibleForums(from: offsets, to: destination, forums: forums)
                }
            } header: {
                Text("已显示")
            } footer: {
                Text("可拖动排序；主页面也支持长按版块标签直接调整。")
            }

            if !hiddenForums.isEmpty {
                Section("未显示") {
                    ForEach(hiddenForums) { forum in
                        HStack {
                            BoardRow(forum: forum)
                            Spacer()
                            Button("显示", systemImage: "plus.circle") {
                                preferences.setVisible(true, forumID: forum.id)
                            }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
        }
        .navigationTitle("版块管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
        .onAppear { preferences.reconcile(with: forums) }
    }
}

private extension Array where Element == Forum {
    func deduplicatedForums() -> [Forum] {
        var ids = Set<Int>()
        return filter { ids.insert($0.id).inserted }
    }
}
