//
// XdnmbAppView.swift
// Author: Maru
//

import SwiftUI

struct XdnmbAppView: View {
    private enum AppTab: Hashable, CaseIterable {
        case home
        case subscriptions
        case history
        case profile

        var title: String {
            switch self {
            case .home: "首页"
            case .subscriptions: "订阅"
            case .history: "历史"
            case .profile: "我的"
            }
        }

        var symbol: String {
            switch self {
            case .home: "house"
            case .subscriptions: "bookmark"
            case .history: "clock.arrow.circlepath"
            case .profile: "person.crop.circle"
            }
        }
    }

    @StateObject private var appModel: AppModel
    @StateObject private var identityStore: IdentityStore
    @StateObject private var boardPreferences: BoardPreferencesStore
    @StateObject private var sessionStore: AppSessionStore
    @StateObject private var postHistory: PostHistoryStore
    @StateObject private var bottomAccessory: AppBottomAccessoryModel
    @State private var selectedTab = AppTab.home
    private let runtimeMode: AppRuntimeMode

    init(
        runtimeMode: AppRuntimeMode = .live,
        apiClient: any XdnmbAPIClient = APIService.shared
    ) {
        self.runtimeMode = runtimeMode
        _bottomAccessory = StateObject(wrappedValue: AppBottomAccessoryModel())
        _sessionStore = StateObject(wrappedValue: AppSessionStore(
            apiClient: apiClient,
            runtimeMode: runtimeMode
        ))
        _boardPreferences = StateObject(wrappedValue: BoardPreferencesStore(preview: runtimeMode.isPreview))
        _postHistory = StateObject(wrappedValue: runtimeMode.isPreview
            ? PostHistoryStore(previewEntries: PreviewFixtures.postHistory)
            : PostHistoryStore()
        )
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

    private var tabContent: some View {
        TabView(selection: $selectedTab) {
            Tab(AppTab.home.title, systemImage: AppTab.home.symbol, value: AppTab.home) {
                NavigationStack { MainFeedScreen() }
                    .xdnmbNavigationChrome()
                    .xdnmbTabBarChrome()
            }

            Tab(
                AppTab.subscriptions.title,
                systemImage: AppTab.subscriptions.symbol,
                value: AppTab.subscriptions
            ) {
                NavigationStack { FeedScreen() }
                    .xdnmbNavigationChrome()
                    .xdnmbTabBarChrome()
            }

            Tab(AppTab.history.title, systemImage: AppTab.history.symbol, value: AppTab.history) {
                NavigationStack { PostHistoryScreen() }
                    .xdnmbNavigationChrome()
                    .xdnmbTabBarChrome()
            }

            Tab(AppTab.profile.title, systemImage: AppTab.profile.symbol, value: AppTab.profile) {
                NavigationStack { ProfileScreen() }
                    .xdnmbNavigationChrome()
                    .xdnmbTabBarChrome()
            }
        }
    }

    @ViewBuilder
    var body: some View {
        if #available(iOS 26.1, *) {
            configuredTabContent
                .tabBarMinimizeBehavior(.onScrollDown)
                .tabViewBottomAccessory(isEnabled: bottomAccessory.isVisible) {
                    AppSystemBottomAccessory(model: bottomAccessory)
                }
        } else if #available(iOS 26.0, *) {
            if bottomAccessory.isVisible {
                configuredTabContent
                    .tabBarMinimizeBehavior(.onScrollDown)
                    .tabViewBottomAccessory {
                        AppSystemBottomAccessory(model: bottomAccessory)
                    }
            } else {
                configuredTabContent
                    .tabBarMinimizeBehavior(.onScrollDown)
            }
        } else {
            configuredTabContent
                .overlay(alignment: .bottom) {
                    if bottomAccessory.isVisible {
                        AppLegacyBottomAccessory(model: bottomAccessory)
                    }
                }
        }
    }

    private var configuredTabContent: some View {
        ZStack {
            AppTheme.groupedBackground
                .ignoresSafeArea()

            tabContent
        }
        .tint(AppTheme.accent)
        .environmentObject(appModel)
        .environmentObject(identityStore)
        .environmentObject(boardPreferences)
        .environmentObject(sessionStore)
        .environmentObject(postHistory)
        .environmentObject(bottomAccessory)
        .environment(\.appRuntimeMode, runtimeMode)
        .task(id: identityStore.browsingCookieID) {
            guard !runtimeMode.isPreview else { return }
            await appModel.bootstrap(userHash: identityStore.browsingUserHash)
        }
    }
}

@available(iOS 26.0, *)
private struct AppSystemBottomAccessory: View {
    @ObservedObject var model: AppBottomAccessoryModel
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    var body: some View {
        Button {
            model.performAction()
        } label: {
            if placement == .inline {
                Image(systemName: model.symbol)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack {
                    Label(model.title, systemImage: model.symbol)
                    Spacer()
                    Image(systemName: "chevron.up")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(model.title)
    }
}

private struct AppLegacyBottomAccessory: View {
    @ObservedObject var model: AppBottomAccessoryModel

    var body: some View {
        Button {
            model.performAction()
        } label: {
            HStack {
                Label(model.title, systemImage: model.symbol)
                Spacer()
                Image(systemName: "chevron.up")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
        .background(.ultraThinMaterial, in: .capsule)
        .overlay {
            Capsule()
                .stroke(.primary.opacity(0.08), lineWidth: 0.5)
        }
        .padding(.horizontal, 12)
        .safeAreaPadding(.bottom, 52)
        .accessibilityLabel(model.title)
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
