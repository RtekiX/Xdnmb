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
    ) async -> Bool {
        guard !isSending else { return false }
        isSending = true
        defer { isSending = false }

        if runtimeMode.isPreview {
            errorMessage = nil
            return true
        }

        do {
            switch destination {
            case .forum(let forumID):
                try await apiClient.createThread(
                    forumID: forumID,
                    content: draft.content,
                    title: draft.title,
                    name: draft.name,
                    imageData: draft.imageData,
                    imageExtension: draft.imageExtension,
                    userHash: userHash
                )
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
            }
            errorMessage = nil
            return true
        } catch is CancellationError {
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func present(error: Error) {
        errorMessage = error.localizedDescription
    }

    func clearError() {
        errorMessage = nil
    }
}
