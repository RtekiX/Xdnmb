//
// BoardDirectoryFeature.swift
// Author: Maru
//

import SwiftUI

struct BoardDirectoryScreen: View {
    @EnvironmentObject private var app: AppModel
    @State private var searchText = ""

    private var filteredGroups: [ForumCategory] {
        app.forumGroups.compactMap { group in
            let forums = group.visibleForums.filter { forum in
                searchText.isEmpty ||
                forum.displayName.localizedCaseInsensitiveContains(searchText) ||
                forum.summary.localizedCaseInsensitiveContains(searchText)
            }
            guard !forums.isEmpty else { return nil }
            return ForumCategory(
                status: group.status,
                id: group.id,
                name: group.name,
                sort: group.sort,
                forums: forums
            )
        }
    }

    var body: some View {
        Group {
            if app.isBootstrapping && app.forumGroups.isEmpty {
                LoadingView(title: "正在加载版块")
            } else if app.forumGroups.isEmpty, let error = app.forumError {
                RetryView(title: "版块加载失败", message: error) { await app.bootstrap() }
            } else if filteredGroups.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                List {
                    ForEach(filteredGroups) { group in
                        Section(group.name) {
                            ForEach(group.forums) { forum in
                                NavigationLink {
                                    ForumScreen(forum: forum)
                                } label: {
                                    BoardRow(forum: forum)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable { await app.bootstrap() }
            }
        }
        .navigationTitle("版块")
        .searchable(text: $searchText, prompt: "搜索版块")
    }
}
