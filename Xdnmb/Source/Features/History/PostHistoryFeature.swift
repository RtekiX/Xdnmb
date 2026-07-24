//
// PostHistoryFeature.swift
// Author: Maru
//

import SwiftUI

private enum PostHistoryFilter: String, CaseIterable, Identifiable {
    case all
    case threads
    case replies

    var id: Self { self }

    var title: String {
        switch self {
        case .all: "全部"
        case .threads: "主题"
        case .replies: "回复"
        }
    }
}

struct PostHistoryScreen: View {
    @EnvironmentObject private var history: PostHistoryStore
    @State private var filter = PostHistoryFilter.all
    @State private var showingClearConfirmation = false

    private var visibleEntries: [PostHistoryEntry] {
        switch filter {
        case .all:
            history.entries
        case .threads:
            history.entries.filter { $0.kind == .thread }
        case .replies:
            history.entries.filter { $0.kind == .reply }
        }
    }

    var body: some View {
        Group {
            if history.entries.isEmpty {
                ContentUnavailableView(
                    "还没有发布记录",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("在本机成功发布的主题和回复会出现在这里。")
                )
            } else {
                List {
                    Section {
                        Picker("历史类型", selection: $filter) {
                            ForEach(PostHistoryFilter.allCases) { item in
                                Text(item.title).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                        .listRowBackground(Color.clear)
                    }

                    if visibleEntries.isEmpty {
                        Section {
                            ContentUnavailableView(
                                "没有\(filter.title)记录",
                                systemImage: "tray"
                            )
                            .frame(maxWidth: .infinity)
                            .listRowBackground(Color.clear)
                        }
                    } else {
                        Section {
                            ForEach(visibleEntries) { entry in
                                historyRow(for: entry)
                                    .swipeActions {
                                        Button("删除", role: .destructive) {
                                            history.remove(id: entry.id)
                                        }
                                    }
                            }
                            .onDelete { offsets in
                                history.remove(at: offsets, in: visibleEntries)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("发布历史")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("清空全部历史", systemImage: "trash", role: .destructive) {
                        showingClearConfirmation = true
                    }
                    .disabled(history.entries.isEmpty)
                } label: {
                    Label("管理历史", systemImage: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog(
            "确定清空全部发布历史？",
            isPresented: $showingClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("清空全部历史", role: .destructive) {
                history.removeAll()
            }
        } message: {
            Text("此操作只删除本机记录，不会删除岛上的主题或回复。")
        }
        .alert("历史记录错误", isPresented: Binding(
            get: { history.persistenceError != nil },
            set: { if !$0 { history.clearPersistenceError() } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(history.persistenceError ?? "")
        }
    }

    @ViewBuilder
    private func historyRow(for entry: PostHistoryEntry) -> some View {
        if let threadID = entry.threadID, threadID > 0 {
            NavigationLink {
                ThreadDetailScreen(threadID: threadID)
            } label: {
                PostHistoryRow(entry: entry)
            }
        } else {
            PostHistoryRow(entry: entry)
                .overlay(alignment: .bottomTrailing) {
                    Label("未能定位串号", systemImage: "exclamationmark.triangle")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                .accessibilityHint("发布已成功，但无法跳转到对应主题")
        }
    }
}

private struct PostHistoryRow: View {
    let entry: PostHistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                Label(entry.kind.title, systemImage: entry.kind == .thread ? "square.and.pencil" : "arrowshape.turn.up.left")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
                if let forumName = entry.forumName?.nilIfBlank {
                    Text(forumName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let threadID = entry.threadID {
                    Text("No.\(threadID)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(entry.createdAt, format: .dateTime.month().day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let title = entry.title.nilIfBlank {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }

            Text(entry.content)
                .font(.body)
                .foregroundStyle(.primary)
                .lineLimit(3)

            HStack(spacing: 10) {
                if let authorName = entry.authorName.nilIfBlank {
                    Label(authorName, systemImage: "person")
                }
                if entry.hasAttachment {
                    Label("含图片", systemImage: "photo")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
