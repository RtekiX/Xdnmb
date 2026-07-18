//
// MainFeedChrome.swift
// Author: Maru
//

import Combine
import SwiftUI

@MainActor
final class MainFeedChromeModel: ObservableObject {
    @Published private(set) var page = 1
    @Published private(set) var pageEnabled = false
    @Published private(set) var leadingTitle = ""
    @Published private(set) var leadingSymbol = "circle"
    @Published private(set) var leadingEnabled = false
    @Published private(set) var primaryTitle = "操作"
    @Published private(set) var primarySymbol = "ellipsis"
    @Published private(set) var primaryEnabled = false

    private var onPageTap: () -> Void = {}
    private var onLeadingTap: () -> Void = {}
    private var onPrimaryTap: () -> Void = {}

    func configure(
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
        self.page = max(page, 1)
        self.pageEnabled = pageEnabled
        self.leadingTitle = leadingTitle
        self.leadingSymbol = leadingSymbol
        self.leadingEnabled = leadingEnabled
        self.primaryTitle = primaryTitle
        self.primarySymbol = primarySymbol
        self.primaryEnabled = primaryEnabled
        self.onPageTap = onPageTap
        self.onLeadingTap = onLeadingTap
        self.onPrimaryTap = onPrimaryTap
    }

    func openPagePicker() { onPageTap() }
    func performLeadingAction() { onLeadingTap() }
    func performPrimaryAction() { onPrimaryTap() }
}

private struct MainFeedNavigationVisibilityHandlerKey: EnvironmentKey {
    static let defaultValue: (Bool) -> Void = { _ in }
}

extension EnvironmentValues {
    var mainFeedNavigationVisibilityHandler: (Bool) -> Void {
        get { self[MainFeedNavigationVisibilityHandlerKey.self] }
        set { self[MainFeedNavigationVisibilityHandlerKey.self] = newValue }
    }
}
