//
// BoardPreferencesStoreStateTests.swift
// Author: Maru
//

import Foundation

@main
@MainActor
struct BoardPreferencesStoreStateTests {
    static func main() async throws {
        try await verifyFreshDefaultsAndUnlimitedResidents()
        try await verifyExistingPreferencesArePreserved()
        try await verifyExistingEmptySelectionIsPreserved()
        print("Board preferences state tests passed")
    }

    private static func verifyFreshDefaultsAndUnlimitedResidents() async throws {
        let suiteName = "BoardPreferencesStoreStateTests-fresh-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw BoardPreferencesStateTestError.failed("could not create isolated defaults")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let forums = makeForums(count: 10)
        let store = BoardPreferencesStore(defaults: defaults)
        store.reconcile(with: forums)

        var residentIDs = store.visibleForums(from: forums).map(\.id)
        try require(residentIDs == [1, 2, 3, 4], "fresh installs should start with four residents")

        for forumID in 5...10 {
            store.setVisible(true, forumID: forumID)
        }
        residentIDs = store.visibleForums(from: forums).map(\.id)
        try require(residentIDs == Array(1...10), "resident boards must not have a quantity limit")

        store.moveVisibleForums(
            from: IndexSet(integer: 9),
            to: 0,
            forums: forums
        )
        residentIDs = store.visibleForums(from: forums).map(\.id)
        try require(residentIDs == [10, 1, 2, 3, 4, 5, 6, 7, 8, 9], "drag reorder must persist")

        let restoredStore = BoardPreferencesStore(defaults: defaults)
        restoredStore.reconcile(with: forums)
        let restoredIDs = restoredStore.visibleForums(from: forums).map(\.id)
        try require(restoredIDs == residentIDs, "relaunch must preserve every resident and its order")
    }

    private static func verifyExistingPreferencesArePreserved() async throws {
        let suiteName = "BoardPreferencesStoreStateTests-existing-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw BoardPreferencesStateTestError.failed("could not create isolated defaults")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(Array(1...12), forKey: "boardPreferences.order")
        defaults.set([], forKey: "boardPreferences.hidden")
        let forums = makeForums(count: 12)
        let store = BoardPreferencesStore(defaults: defaults)
        store.reconcile(with: forums)
        let residentIDs = store.visibleForums(from: forums).map(\.id)
        try require(
            residentIDs == Array(1...12),
            "migration must not trim an existing unlimited resident selection"
        )
    }

    private static func verifyExistingEmptySelectionIsPreserved() async throws {
        let suiteName = "BoardPreferencesStoreStateTests-empty-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw BoardPreferencesStateTestError.failed("could not create isolated defaults")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(Array(1...6), forKey: "boardPreferences.order")
        defaults.set(Array(1...6), forKey: "boardPreferences.hidden")
        let forums = makeForums(count: 6)
        let store = BoardPreferencesStore(defaults: defaults)
        store.reconcile(with: forums)
        try require(
            store.visibleForums(from: forums).isEmpty,
            "migration must preserve an existing empty resident selection"
        )
    }

    private static func makeForums(count: Int) -> [Forum] {
        (1...count).map {
            Forum(id: $0, name: "版块\($0)", message: "")
        }
    }

    private static func require(_ condition: Bool, _ message: String) throws {
        guard condition else { throw BoardPreferencesStateTestError.failed(message) }
    }
}

private enum BoardPreferencesStateTestError: LocalizedError {
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .failed(let message): return message
        }
    }
}
