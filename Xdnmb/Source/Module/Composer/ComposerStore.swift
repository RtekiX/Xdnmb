//
// ComposerStore.swift
// Author: Maru
//

import Combine
import Foundation

enum ComposerDestination: Sendable {
    case forum(Int)
    case thread(Int)
}

struct ComposerSubmission: Sendable {
    let destination: ComposerDestination
    let threadID: Int?
}

struct ComposerDraft: Sendable {
    let content: String
    let title: String
    let name: String
    let imageData: Data?
    let imageExtension: String?
}

@MainActor
final class ComposerStore: ObservableObject {
    @Published private(set) var isSending = false
    @Published private(set) var errorMessage: String?

    private let apiClient: any XdnmbAPIClient
    private let runtimeMode: AppRuntimeMode

    init(apiClient: any XdnmbAPIClient, runtimeMode: AppRuntimeMode) {
        self.apiClient = apiClient
        self.runtimeMode = runtimeMode
    }

    func submit(
        destination: ComposerDestination,
        draft: ComposerDraft,
        userHash: String
    ) async -> ComposerSubmission? {
        guard !isSending else { return nil }
        isSending = true
        defer { isSending = false }

        if runtimeMode.isPreview {
            errorMessage = nil
            let threadID: Int?
            switch destination {
            case .forum:
                threadID = PreviewFixtures.threads.first?.id
            case .thread(let id):
                threadID = id
            }
            return ComposerSubmission(destination: destination, threadID: threadID)
        }

        do {
            switch destination {
            case .forum(let forumID):
                let previousPostID = try? await apiClient.lastPost(userHash: userHash).id
                try await apiClient.createThread(
                    forumID: forumID,
                    content: draft.content,
                    title: draft.title,
                    name: draft.name,
                    imageData: draft.imageData,
                    imageExtension: draft.imageExtension,
                    userHash: userHash
                )
                let threadID = await resolveNewThreadID(
                    userHash: userHash,
                    previousPostID: previousPostID
                )
                errorMessage = nil
                return ComposerSubmission(destination: destination, threadID: threadID)
            case .thread(let threadID):
                try await apiClient.reply(
                    threadID: threadID,
                    content: draft.content,
                    title: draft.title,
                    name: draft.name,
                    imageData: draft.imageData,
                    imageExtension: draft.imageExtension,
                    userHash: userHash
                )
                errorMessage = nil
                return ComposerSubmission(destination: destination, threadID: threadID)
            }
        } catch is CancellationError {
            return nil
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func present(error: Error) {
        errorMessage = error.localizedDescription
    }

    func clearError() {
        errorMessage = nil
    }

    private func resolveNewThreadID(
        userHash: String,
        previousPostID: Int?
    ) async -> Int? {
        for attempt in 0..<3 {
            if attempt > 0 {
                try? await Task.sleep(for: .milliseconds(250 * attempt))
            }
            guard let latest = try? await apiClient.lastPost(userHash: userHash) else {
                continue
            }
            if previousPostID == nil || latest.id != previousPostID {
                return latest.threadID
            }
        }
        return nil
    }
}
