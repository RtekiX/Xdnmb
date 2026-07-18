//
// BoardPreferencesStore.swift
// Author: Maru
//

import Combine
import Foundation

@MainActor
final class BoardPreferencesStore: ObservableObject {
    @Published private(set) var orderedForumIDs: [Int]
    @Published private(set) var hiddenForumIDs: Set<Int>

    private let persistsChanges: Bool
    private let defaults: UserDefaults
    private let orderKey = "boardPreferences.order"
    private let hiddenKey = "boardPreferences.hidden"

    init(preview: Bool = false, defaults: UserDefaults = .standard) {
        persistsChanges = !preview
        self.defaults = defaults
        orderedForumIDs = preview ? [] : defaults.array(forKey: orderKey) as? [Int] ?? []
        hiddenForumIDs = preview ? [] : Set(defaults.array(forKey: hiddenKey) as? [Int] ?? [])
    }

    func reconcile(with forums: [Forum]) {
        let validIDs = Set(forums.map(\.id))
        var seen = Set<Int>()
        let retained = orderedForumIDs.filter { validIDs.contains($0) && seen.insert($0).inserted }
        let missing = forums.map(\.id).filter { !seen.contains($0) }
        orderedForumIDs = retained + missing
        hiddenForumIDs.formIntersection(validIDs)
        persist()
    }

    func orderedForums(from forums: [Forum]) -> [Forum] {
        let byID = Dictionary(uniqueKeysWithValues: forums.map { ($0.id, $0) })
        let ordered = orderedForumIDs.compactMap { byID[$0] }
        let knownIDs = Set(ordered.map(\.id))
        return ordered + forums.filter { !knownIDs.contains($0.id) }
    }

    func visibleForums(from forums: [Forum]) -> [Forum] {
        orderedForums(from: forums).filter { !hiddenForumIDs.contains($0.id) }
    }

    func hiddenForums(from forums: [Forum]) -> [Forum] {
        orderedForums(from: forums).filter { hiddenForumIDs.contains($0.id) }
    }

    func setVisible(_ isVisible: Bool, forumID: Int) {
        if isVisible {
            hiddenForumIDs.remove(forumID)
        } else {
            hiddenForumIDs.insert(forumID)
        }
        persist()
    }

    func move(forumID: Int, before destinationID: Int) {
        guard forumID != destinationID,
              let sourceIndex = orderedForumIDs.firstIndex(of: forumID) else { return }
        orderedForumIDs.remove(at: sourceIndex)
        guard let destinationIndex = orderedForumIDs.firstIndex(of: destinationID) else {
            orderedForumIDs.append(forumID)
            persist()
            return
        }
        orderedForumIDs.insert(forumID, at: destinationIndex)
        persist()
    }

    func moveVisibleForums(from offsets: IndexSet, to destination: Int, forums: [Forum]) {
        var visibleIDs = visibleForums(from: forums).map(\.id)
        let movingIDs = offsets.map { visibleIDs[$0] }
        for index in offsets.sorted(by: >) {
            visibleIDs.remove(at: index)
        }
        let removedBeforeDestination = offsets.filter { $0 < destination }.count
        let insertionIndex = min(max(destination - removedBeforeDestination, 0), visibleIDs.count)
        visibleIDs.insert(contentsOf: movingIDs, at: insertionIndex)
        var iterator = visibleIDs.makeIterator()
        orderedForumIDs = orderedForumIDs.map { id in
            hiddenForumIDs.contains(id) ? id : (iterator.next() ?? id)
        }
        persist()
    }

    private func persist() {
        guard persistsChanges else { return }
        defaults.set(orderedForumIDs, forKey: orderKey)
        defaults.set(Array(hiddenForumIDs).sorted(), forKey: hiddenKey)
    }
}
