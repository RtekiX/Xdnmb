//
// AppTheme.swift
// Author: Maru
//

import SwiftUI

enum AppTheme {
    static let accent = Color.accentColor
    static let card = Color(uiColor: .secondarySystemBackground)
    static let elevated = Color(uiColor: .systemBackground)
    static let groupedBackground = Color(uiColor: .systemGroupedBackground)
}

extension View {
    @ViewBuilder
    func xdnmbSoftScrollEdgeEffect(for edges: Edge.Set = .top) -> some View {
        if #available(iOS 26.0, *) {
            scrollEdgeEffectStyle(.soft, for: edges)
        } else {
            self
        }
    }

    @ViewBuilder
    func xdnmbNavigationChrome() -> some View {
        if #available(iOS 26.0, *) {
            toolbarBackground(.hidden, for: .navigationBar)
        } else {
            toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        }
    }

    @ViewBuilder
    func xdnmbTabBarChrome() -> some View {
        if #available(iOS 26.0, *) {
            toolbarBackground(.hidden, for: .tabBar)
        } else {
            toolbarBackground(.ultraThinMaterial, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
        }
    }

    @ViewBuilder
    func xdnmbNavigationTitle(
        _ title: String,
        isEnabled: Bool
    ) -> some View {
        if isEnabled {
            navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
        } else {
            self
        }
    }
}
