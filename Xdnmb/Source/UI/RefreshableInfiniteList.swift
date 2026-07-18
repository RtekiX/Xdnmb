//
// RefreshableInfiniteList.swift
// Author: Maru
//

import SwiftUI

private struct InfiniteListTrigger<ID: Hashable>: Hashable {
    let lastID: ID?
    let canLoadMore: Bool
}

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
    let scrollPosition: Binding<Items.Element.ID?>
    let onRefresh: () async -> Void
    let onLoadMore: () async -> Void
    @ViewBuilder let header: () -> Header
    @ViewBuilder let row: (Items.Element) -> Row
    @ViewBuilder let footer: () -> Footer

    @State private var isRefreshing = false
    @Environment(\.mainFeedNavigationVisibilityHandler) private var reportNavigationVisibility

    private let topAnchor = "refreshable-infinite-list-top"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    Color.clear
                        .frame(height: 0)
                        .id(topAnchor)
                    header()
                    ForEach(items) { item in
                        row(item)
                            .task(id: InfiniteListTrigger(
                                lastID: items.last?.id,
                                canLoadMore: canLoadMore
                            )) {
                                guard item.id == items.last?.id,
                                      canLoadMore,
                                      !isLoadingMore else { return }
                                await onLoadMore()
                            }
                    }
                    if isLoadingMore && !isRefreshing {
                        ProgressView("正在加载更多…")
                            .padding(.vertical, 12)
                    } else {
                        footer()
                    }
                }
                .scrollTargetLayout()
                .padding(16)
            }
            .scrollPosition(id: scrollPosition, anchor: .top)
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                max(geometry.contentOffset.y + geometry.contentInsets.top, 0)
            } action: { oldOffset, newOffset in
                if newOffset < 12 {
                    reportNavigationVisibility(true)
                } else if abs(newOffset - oldOffset) > 5 {
                    reportNavigationVisibility(newOffset < oldOffset)
                }
            }
            .refreshable {
                isRefreshing = true
                await onRefresh()
                isRefreshing = false
            }
            .onChange(of: scrollToTopRequest) {
                withAnimation { proxy.scrollTo(topAnchor, anchor: .top) }
            }
        }
    }
}
