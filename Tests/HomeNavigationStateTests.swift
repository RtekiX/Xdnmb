//
// HomeNavigationStateTests.swift
// Author: Maru
//

import Foundation

@main
@MainActor
struct HomeNavigationStateTests {
    static func main() throws {
        let state = HomeNavigationState()

        try require(
            approximatelyEqual(state.revealProgress, 1),
            "navigation must start fully revealed"
        )

        state.recordScrollOffset(0)
        state.recordScrollOffset(14)
        try require(
            approximatelyEqual(state.revealProgress, 0.75),
            "downward scrolling must continuously reduce reveal progress"
        )

        state.recordScrollOffset(28)
        try require(
            approximatelyEqual(state.revealProgress, 0.5),
            "half of the travel distance must produce half reveal"
        )

        state.recordScrollOffset(56)
        try require(
            approximatelyEqual(state.revealProgress, 0),
            "the full travel distance must hide the source rail"
        )
        state.settle()

        state.recordScrollOffset(28)
        try require(
            approximatelyEqual(state.revealProgress, 0.5),
            "upward scrolling must restore progress at the same rate"
        )

        state.settle()
        try require(
            approximatelyEqual(state.revealProgress, 1),
            "an idle half-revealed rail must settle to a complete state"
        )
        state.beginSourceTransition()
        state.recordScrollOffset(240)
        try require(
            approximatelyEqual(state.revealProgress, 1),
            "the first offset from a new source must establish a baseline"
        )
        state.recordScrollOffset(268)
        try require(
            approximatelyEqual(state.revealProgress, 0.5),
            "a new source must continue to track scroll displacement"
        )

        state.recordScrollOffset(0)
        try require(
            approximatelyEqual(state.revealProgress, 1),
            "returning to the top must always restore navigation"
        )

        state.hideSources()
        state.recordScrollOffset(100, allowsAutomaticCollapse: false)
        try require(
            approximatelyEqual(state.revealProgress, 1),
            "accessibility protection must keep the source bar expanded"
        )

        var didPerformAccessoryAction = false
        let accessory = AppBottomAccessoryModel()
        accessory.configure(
            ownerID: "thread-1",
            title: "回复这个帖子",
            symbol: "arrowshape.turn.up.left",
            action: { didPerformAccessoryAction = true }
        )
        try require(accessory.isVisible, "configured bottom accessory must be visible")
        accessory.performAction()
        try require(didPerformAccessoryAction, "bottom accessory must retain its action")
        accessory.clear(ownerID: "thread-2")
        try require(accessory.isVisible, "a different owner must not clear the accessory")
        accessory.clear(ownerID: "thread-1")
        try require(!accessory.isVisible, "the active owner must be able to clear the accessory")

        print("Home navigation state tests passed")
    }

    private static func require(_ condition: Bool, _ message: String) throws {
        guard condition else { throw HomeNavigationStateTestError.failed(message) }
    }

    private static func approximatelyEqual(
        _ lhs: CGFloat,
        _ rhs: CGFloat,
        tolerance: CGFloat = 0.001
    ) -> Bool {
        abs(lhs - rhs) <= tolerance
    }
}

private enum HomeNavigationStateTestError: LocalizedError {
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .failed(let message): return message
        }
    }
}
