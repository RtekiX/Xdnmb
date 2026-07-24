//
// RefreshableInfiniteList.swift
// Author: Maru
//

import SwiftUI

struct RefreshableInfiniteList<Items, Header, Row, Footer>: View
where Items: RandomAccessCollection,
      Items.Element: Identifiable,
      Items.Element.ID: Hashable,
      Header: View,
      Row: View,
      Footer: View {
    let items: Items
    let isLoadingMore: Bool
    let canLoadMore: Bool
    let scrollToTopRequest: Int
    let topContentMargin: CGFloat
    let onRefresh: () async -> Void
    let onLoadMore: () async -> Void
    let onScrollOffsetChange: (CGFloat) -> Void
    let onScrollPhaseChange: (Bool) -> Void
    @ViewBuilder let header: () -> Header
    @ViewBuilder let row: (Items.Element) -> Row
    @ViewBuilder let footer: () -> Footer

    @State private var isRefreshing = false

    private let topAnchor = "refreshable-infinite-list-top"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    Color.clear
                        .frame(height: 0)
                        .id(topAnchor)
                    header()
                    ForEach(items) { item in
                        row(item)
                    }
                    if canLoadMore {
                        InfiniteListLoadMoreTrigger(
                            triggerID: items.last?.id,
                            isLoading: isLoadingMore,
                            onLoadMore: onLoadMore
                        )
                    } else if isLoadingMore && !isRefreshing {
                        ProgressView("正在加载…")
                            .padding(.vertical, 12)
                    } else {
                        footer()
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .contentMargins(.top, topContentMargin, for: .scrollContent)
            .refreshable {
                isRefreshing = true
                await onRefresh()
                isRefreshing = false
            }
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                max(geometry.contentOffset.y + geometry.contentInsets.top, 0)
            } action: { _, newOffset in
                onScrollOffsetChange(newOffset)
            }
            .onScrollPhaseChange { _, newPhase in
                onScrollPhaseChange(newPhase.isScrolling)
            }
            .xdnmbSoftScrollEdgeEffect()
            .onChange(of: scrollToTopRequest) {
                withAnimation { proxy.scrollTo(topAnchor, anchor: .top) }
            }
        }
    }

    init(
        items: Items,
        isLoadingMore: Bool,
        canLoadMore: Bool,
        scrollToTopRequest: Int,
        topContentMargin: CGFloat = 0,
        onRefresh: @escaping () async -> Void,
        onLoadMore: @escaping () async -> Void,
        onScrollOffsetChange: @escaping (CGFloat) -> Void = { _ in },
        onScrollPhaseChange: @escaping (Bool) -> Void = { _ in },
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder row: @escaping (Items.Element) -> Row,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.items = items
        self.isLoadingMore = isLoadingMore
        self.canLoadMore = canLoadMore
        self.scrollToTopRequest = scrollToTopRequest
        self.topContentMargin = max(topContentMargin, 0)
        self.onRefresh = onRefresh
        self.onLoadMore = onLoadMore
        self.onScrollOffsetChange = onScrollOffsetChange
        self.onScrollPhaseChange = onScrollPhaseChange
        self.header = header
        self.row = row
        self.footer = footer
    }
}

private struct InfiniteListLoadMoreTrigger<ID: Hashable>: View {
    let triggerID: ID?
    let isLoading: Bool
    let onLoadMore: () async -> Void

    var body: some View {
        ProgressView(isLoading ? "正在加载更多…" : "继续加载")
            .padding(.vertical, 12)
            .task(id: triggerID) {
                guard !isLoading else { return }
                await onLoadMore()
            }
    }
}
