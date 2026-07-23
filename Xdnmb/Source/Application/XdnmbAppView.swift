//
// XdnmbAppView.swift
// Author: Maru
//

import SwiftUI

struct XdnmbAppView: View {
    @StateObject private var appModel: AppModel
    @StateObject private var identityStore: IdentityStore
    @StateObject private var boardPreferences: BoardPreferencesStore
    @StateObject private var sessionStore: AppSessionStore
    private let runtimeMode: AppRuntimeMode

    init(
        runtimeMode: AppRuntimeMode = .live,
        apiClient: any XdnmbAPIClient = APIService.shared
    ) {
        self.runtimeMode = runtimeMode
        _sessionStore = StateObject(wrappedValue: AppSessionStore(
            apiClient: apiClient,
            runtimeMode: runtimeMode
        ))
        _boardPreferences = StateObject(wrappedValue: BoardPreferencesStore(preview: runtimeMode.isPreview))
        if runtimeMode.isPreview {
            _appModel = StateObject(wrappedValue: AppModel(
                apiClient: apiClient,
                forumGroups: PreviewFixtures.forumGroups,
                timelines: PreviewFixtures.timelines,
                notice: PreviewFixtures.notice,
                subscribedThreadIDs: Set(PreviewFixtures.feedEntries.map(\.id))
            ))
            _identityStore = StateObject(wrappedValue: IdentityStore(
                previewUserHash: PreviewFixtures.userHash,
                feedID: PreviewFixtures.feedID
            ))
        } else {
            _appModel = StateObject(wrappedValue: AppModel(apiClient: apiClient))
            _identityStore = StateObject(wrappedValue: IdentityStore())
        }
    }

    var body: some View {
        TabView {
            NavigationStack { MainFeedScreen() }
                .tabItem { Label("浏览", systemImage: "sparkles.rectangle.stack") }

            NavigationStack { BoardDirectoryScreen() }
                .tabItem { Label("版块", systemImage: "square.grid.2x2") }

            NavigationStack { FeedScreen() }
                .tabItem { Label("订阅", systemImage: "bookmark") }

            NavigationStack { ProfileScreen() }
                .tabItem { Label("我的", systemImage: "person.crop.circle") }
        }
        .tint(AppTheme.accent)
        .environmentObject(appModel)
        .environmentObject(identityStore)
        .environmentObject(boardPreferences)
        .environmentObject(sessionStore)
        .environment(\.appRuntimeMode, runtimeMode)
        .task(id: identityStore.browsingCookieID) {
            guard !runtimeMode.isPreview else { return }
            await appModel.bootstrap(userHash: identityStore.browsingUserHash)
        }
    }
}

#Preview("Xdnmb · 浅色") {
    XdnmbAppView(runtimeMode: .preview)
        .preferredColorScheme(.light)
}

#Preview("Xdnmb · 深色") {
    XdnmbAppView(runtimeMode: .preview)
        .preferredColorScheme(.dark)
}
