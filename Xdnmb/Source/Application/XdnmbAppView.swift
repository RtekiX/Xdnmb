//
// XdnmbAppView.swift
// Author: Maru
//

import SwiftUI

struct XdnmbAppView: View {
    @StateObject private var appModel = AppModel()
    @StateObject private var identityStore = IdentityStore()

    var body: some View {
        TabView {
            NavigationStack { TimelineScreen() }
                .tabItem { Label("时间线", systemImage: "sparkles.rectangle.stack") }

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
        .task { await appModel.bootstrap() }
    }
}
