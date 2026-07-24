//
// MainFeedChrome.swift
// Author: Maru
//

import Combine
import SwiftUI

@MainActor
final class HomeNavigationState: ObservableObject {
    @Published private(set) var revealProgress: CGFloat = 1
    @Published private(set) var hidesBottomBar = false

    private let travelDistance: CGFloat
    private var lastOffset: CGFloat?

    init(travelDistance: CGFloat = 56) {
        self.travelDistance = max(travelDistance, 1)
    }

    var isExpanded: Bool {
        revealProgress >= 0.5
    }

    var acceptsSourceInteraction: Bool {
        revealProgress >= 0.9
    }

    func recordScrollOffset(_ offset: CGFloat, allowsAutomaticCollapse: Bool = true) {
        let normalizedOffset = max(offset, 0)
        guard allowsAutomaticCollapse else {
            showSources()
            lastOffset = normalizedOffset
            return
        }

        if normalizedOffset <= 1 {
            showSources()
            lastOffset = normalizedOffset
            return
        }

        guard let lastOffset else {
            self.lastOffset = normalizedOffset
            return
        }

        let delta = normalizedOffset - lastOffset
        self.lastOffset = normalizedOffset
        guard abs(delta) >= 0.25 else { return }

        revealProgress = min(
            max(revealProgress - (delta / travelDistance), 0),
            1
        )
    }

    func showSources() {
        revealProgress = 1
        hidesBottomBar = false
    }

    func hideSources() {
        revealProgress = 0
        hidesBottomBar = true
    }

    func settle() {
        if isExpanded {
            showSources()
        } else {
            hideSources()
        }
    }

    func beginSourceTransition() {
        revealProgress = 1
        hidesBottomBar = false
        lastOffset = nil
    }
}

@MainActor
final class HomeFeedChromeModel: ObservableObject {
    @Published private(set) var navigationTitle = "综合线"
    @Published private(set) var page = 1
    @Published private(set) var pageEnabled = false
    @Published private(set) var leadingTitle = ""
    @Published private(set) var leadingSymbol = "circle"
    @Published private(set) var leadingEnabled = false
    @Published private(set) var primaryTitle = ""
    @Published private(set) var primarySymbol = "circle"
    @Published private(set) var primaryEnabled = false

    private var onPageTap: () -> Void = {}
    private var onLeadingTap: () -> Void = {}
    private var onPrimaryTap: () -> Void = {}

    func configure(
        navigationTitle: String,
        page: Int,
        pageEnabled: Bool,
        leadingTitle: String,
        leadingSymbol: String,
        leadingEnabled: Bool = true,
        primaryTitle: String,
        primarySymbol: String,
        primaryEnabled: Bool = true,
        onLeadingTap: @escaping () -> Void,
        onPageTap: @escaping () -> Void,
        onPrimaryTap: @escaping () -> Void
    ) {
        self.navigationTitle = navigationTitle
        self.page = max(page, 1)
        self.pageEnabled = pageEnabled
        self.leadingTitle = leadingTitle
        self.leadingSymbol = leadingSymbol
        self.leadingEnabled = leadingEnabled
        self.primaryTitle = primaryTitle
        self.primarySymbol = primarySymbol
        self.primaryEnabled = primaryEnabled
        self.onLeadingTap = onLeadingTap
        self.onPageTap = onPageTap
        self.onPrimaryTap = onPrimaryTap
    }

    func performLeadingAction() { onLeadingTap() }
    func openPagePicker() { onPageTap() }
    func performPrimaryAction() { onPrimaryTap() }
}

@MainActor
final class AppBottomAccessoryModel: ObservableObject {
    @Published private(set) var isVisible = false
    @Published private(set) var title = ""
    @Published private(set) var symbol = "bubble.left"

    private var ownerID: String?
    private var action: () -> Void = {}

    func configure(
        ownerID: String,
        title: String,
        symbol: String,
        action: @escaping () -> Void
    ) {
        self.ownerID = ownerID
        self.title = title
        self.symbol = symbol
        self.action = action
        isVisible = true
    }

    func clear(ownerID: String) {
        guard self.ownerID == ownerID else { return }
        self.ownerID = nil
        action = {}
        isVisible = false
    }

    func performAction() {
        action()
    }
}

@MainActor
final class AppNavigationChromeModel: ObservableObject {
    @Published private(set) var isBottomBarVisible = true

    func setBottomBarVisible(_ isVisible: Bool) {
        isBottomBarVisible = isVisible
    }

    func showBottomBar() {
        isBottomBarVisible = true
    }
}
