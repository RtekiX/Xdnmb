//
// XdnmbAppView.swift
// Author: Maru
//

import SwiftUI

struct XdnmbAppView: View {
    private enum AppTab: Hashable, CaseIterable {
        case home
        case subscriptions
        case profile

        var title: String {
            switch self {
            case .home: "首页"
            case .subscriptions: "订阅"
            case .profile: "我的"
            }
        }

        var symbol: String {
            switch self {
            case .home: "house"
            case .subscriptions: "bookmark"
            case .profile: "person.crop.circle"
            }
        }
    }

    @StateObject private var appModel: AppModel
    @StateObject private var identityStore: IdentityStore
    @StateObject private var boardPreferences: BoardPreferencesStore
    @StateObject private var sessionStore: AppSessionStore
    @StateObject private var bottomAccessory: AppBottomAccessoryModel
    @StateObject private var navigationChrome: AppNavigationChromeModel
    @State private var selectedTab = AppTab.home
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let runtimeMode: AppRuntimeMode

    init(
        runtimeMode: AppRuntimeMode = .live,
        apiClient: any XdnmbAPIClient = APIService.shared
    ) {
        self.runtimeMode = runtimeMode
        _bottomAccessory = StateObject(wrappedValue: AppBottomAccessoryModel())
        _navigationChrome = StateObject(wrappedValue: AppNavigationChromeModel())
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

    private var tabContent: some View {
        ZStack {
            tabLayer(.home) {
                NavigationStack { MainFeedScreen() }
                    .xdnmbNavigationChrome()
            }

            tabLayer(.subscriptions) {
                NavigationStack { FeedScreen() }
                    .xdnmbNavigationChrome()
            }

            tabLayer(.profile) {
                NavigationStack { ProfileScreen() }
                    .xdnmbNavigationChrome()
            }
        }
    }

    private func tabLayer<Content: View>(
        _ tab: AppTab,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .opacity(selectedTab == tab ? 1 : 0)
            .allowsHitTesting(selectedTab == tab)
            .accessibilityHidden(selectedTab != tab)
            .zIndex(selectedTab == tab ? 1 : 0)
    }

    var body: some View {
        tabContent
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if navigationChrome.isBottomBarVisible || bottomAccessory.isVisible {
                AppBottomDock(
                    tabs: AppTab.allCases,
                    selectedTab: $selectedTab,
                    bottomAccessory: bottomAccessory,
                    title: \.title,
                    symbol: \.symbol
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(
            reduceMotion ? .easeOut(duration: 0.12) : .snappy(duration: 0.24),
            value: navigationChrome.isBottomBarVisible || bottomAccessory.isVisible
        )
        .tint(AppTheme.accent)
        .environmentObject(appModel)
        .environmentObject(identityStore)
        .environmentObject(boardPreferences)
        .environmentObject(sessionStore)
        .environmentObject(bottomAccessory)
        .environmentObject(navigationChrome)
        .environment(\.appRuntimeMode, runtimeMode)
        .onChange(of: selectedTab) {
            navigationChrome.showBottomBar()
        }
        .task(id: identityStore.browsingCookieID) {
            guard !runtimeMode.isPreview else { return }
            await appModel.bootstrap(userHash: identityStore.browsingUserHash)
        }
    }
}

private struct AppBottomDock<Tab: Hashable>: View {
    let tabs: [Tab]
    @Binding var selectedTab: Tab
    @ObservedObject var bottomAccessory: AppBottomAccessoryModel
    let title: KeyPath<Tab, String>
    let symbol: KeyPath<Tab, String>

    var body: some View {
        VStack(spacing: 6) {
            if bottomAccessory.isVisible {
                dockSurface {
                    Button {
                        bottomAccessory.performAction()
                    } label: {
                        HStack {
                            Label(bottomAccessory.title, systemImage: bottomAccessory.symbol)
                            Spacer()
                            Image(systemName: "chevron.up")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding(.horizontal, 16)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(bottomAccessory.title)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            dockSurface {
                HStack {
                    ForEach(tabs, id: \.self) { tab in
                        Button {
                            selectedTab = tab
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: tab[keyPath: symbol])
                                    .font(.system(size: 17, weight: .semibold))
                                Text(tab[keyPath: title])
                                    .font(.caption2.weight(.medium))
                            }
                            .foregroundStyle(selectedTab == tab ? AppTheme.accent : .secondary)
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityValue(selectedTab == tab ? "已选择" : "未选择")
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private func dockSurface<Content: View>(
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

#Preview("Xdnmb · 浅色") {
    XdnmbAppView(runtimeMode: .preview)
        .preferredColorScheme(.light)
}

#Preview("Xdnmb · 深色") {
    XdnmbAppView(runtimeMode: .preview)
        .preferredColorScheme(.dark)
}
