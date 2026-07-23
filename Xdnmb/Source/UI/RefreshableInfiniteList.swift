//
// RefreshableInfiniteList.swift
// Author: Maru
//

import SwiftUI

private struct ScrollNavigationVisibilityTracker {
    private enum Direction {
        case towardTop
        case towardBottom
    }

    private static let topRevealOffset: CGFloat = 12
    private static let hideDistance: CGFloat = 48
    private static let revealDistance: CGFloat = 48

    private var previousOffset: CGFloat?
    private var direction: Direction?
    private var accumulatedDistance: CGFloat = 0

    mutating func consume(offset rawOffset: CGFloat) -> Bool? {
        let offset = max(rawOffset, 0)

        guard let previousOffset else {
            self.previousOffset = offset
            return offset <= Self.topRevealOffset ? true : nil
        }

        self.previousOffset = offset

        if offset <= Self.topRevealOffset {
            resetAccumulation()
            return true
        }

        let delta = offset - previousOffset
        guard delta != 0 else { return nil }

        let newDirection: Direction = delta > 0 ? .towardBottom : .towardTop
        if direction == newDirection {
            accumulatedDistance += abs(delta)
        } else {
            direction = newDirection
            accumulatedDistance = abs(delta)
        }

        let threshold = newDirection == .towardBottom
            ? Self.hideDistance
            : Self.revealDistance
        guard accumulatedDistance >= threshold else { return nil }

        resetAccumulation()
        return newDirection == .towardTop
    }

    private mutating func resetAccumulation() {
        direction = nil
        accumulatedDistance = 0
    }
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
    let onRefresh: () async -> Void
    let onLoadMore: () async -> Void
    @ViewBuilder let header: () -> Header
    @ViewBuilder let row: (Items.Element) -> Row
    @ViewBuilder let footer: () -> Footer

    @State private var isRefreshing = false
    @State private var navigationVisibilityTracker = ScrollNavigationVisibilityTracker()
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
                .padding(16)
            }
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                max(geometry.contentOffset.y + geometry.contentInsets.top, 0)
            } action: { _, newOffset in
                guard let shouldShow = navigationVisibilityTracker.consume(offset: newOffset) else {
                    return
                }
                reportNavigationVisibility(shouldShow)
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
