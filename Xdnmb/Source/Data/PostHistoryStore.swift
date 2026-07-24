//
// PostHistoryStore.swift
// Author: Maru
//

import Combine
import Foundation

enum PostHistoryKind: String, Codable, CaseIterable, Sendable {
    case thread
    case reply

    var title: String {
        switch self {
        case .thread: "主题"
        case .reply: "回复"
        }
    }
}

struct PostHistoryEntry: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let kind: PostHistoryKind
    let createdAt: Date
    let threadID: Int?
    let forumID: Int?
    let forumName: String?
    let title: String
    let content: String
    let authorName: String
    let hasAttachment: Bool
}

@MainActor
final class PostHistoryStore: ObservableObject {
    @Published private(set) var entries: [PostHistoryEntry]
    @Published private(set) var persistenceError: String?

    private let storageURL: URL?

    init() {
        storageURL = Self.defaultStorageURL()
        entries = []
        load()
    }

    init(previewEntries: [PostHistoryEntry]) {
        storageURL = nil
        entries = previewEntries.sorted { $0.createdAt > $1.createdAt }
    }

    init(storageURL: URL) {
        self.storageURL = storageURL
        entries = []
        load()
    }

    func record(_ entry: PostHistoryEntry) {
        entries.insert(entry, at: 0)
        persist()
    }

    func remove(id: UUID) {
        entries.removeAll { $0.id == id }
        persist()
    }

    func remove(at offsets: IndexSet, in visibleEntries: [PostHistoryEntry]) {
        let ids = Set(offsets.compactMap { index in
            visibleEntries.indices.contains(index) ? visibleEntries[index].id : nil
        })
        guard !ids.isEmpty else { return }
        entries.removeAll { ids.contains($0.id) }
        persist()
    }

    func removeAll() {
        guard !entries.isEmpty else { return }
        entries = []
        persist()
    }

    func clearPersistenceError() {
        persistenceError = nil
    }

    private func load() {
        guard let storageURL, FileManager.default.fileExists(atPath: storageURL.path) else {
            return
        }
        do {
            let data = try Data(contentsOf: storageURL)
            entries = try Self.decoder.decode([PostHistoryEntry].self, from: data)
                .sorted { $0.createdAt > $1.createdAt }
            persistenceError = nil
        } catch {
            entries = []
            persistenceError = "无法读取本机发布历史，原文件没有被覆盖。"
        }
    }

    private func persist() {
        guard let storageURL else { return }
        do {
            try FileManager.default.createDirectory(
                at: storageURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try Self.encoder.encode(entries)
            try data.write(to: storageURL, options: .atomic)
            persistenceError = nil
        } catch {
            persistenceError = "无法保存本机发布历史，请检查设备存储空间。"
        }
    }

    private static func defaultStorageURL() -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("Xdnmb", isDirectory: true)
            .appendingPathComponent("post-history.json", isDirectory: false)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
