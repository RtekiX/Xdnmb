//
// ComposerFeature.swift
// Author: Maru
//

import PhotosUI
import SwiftUI
import UIKit

enum ComposerMode {
    case thread(Forum)
    case reply(Int)

    var title: String {
        switch self {
        case .thread(let forum): return "发布到 \(forum.displayName)"
        case .reply(let id): return "回复 No.\(id)"
        }
    }
}

struct ComposerScreen: View {
    let mode: ComposerMode
    @ObservedObject var identity: IdentityStore
    let onSuccess: () async -> Void

    @EnvironmentObject private var sessions: AppSessionStore

    var body: some View {
        ComposerScreenContent(
            mode: mode,
            identity: identity,
            model: sessions.makeComposerStore(),
            onSuccess: onSuccess
        )
    }
}

private struct ComposerScreenContent: View {
    let mode: ComposerMode
    @ObservedObject var identity: IdentityStore
    let onSuccess: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var history: PostHistoryStore
    @StateObject private var model: ComposerStore
    @State private var content = ""
    @State private var title = ""
    @State private var name = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var attachment: ImageAttachment?
    @State private var isPreparingImage = false
    @State private var selectedCookieID: UUID?
    @FocusState private var editorFocused: Bool

    init(
        mode: ComposerMode,
        identity: IdentityStore,
        model: ComposerStore,
        onSuccess: @escaping () async -> Void
    ) {
        self.mode = mode
        self.identity = identity
        self.onSuccess = onSuccess
        _model = StateObject(wrappedValue: model)
        _selectedCookieID = State(initialValue: identity.postingCookieID)
    }

    var body: some View {
        NavigationStack {
            Form {
                if !identity.hasIdentity {
                    Section {
                        Label("请先在“我的”中通过二维码导入饼干", systemImage: "exclamationmark.shield")
                            .foregroundStyle(.orange)
                    }
                } else {
                    Section("本次使用的饼干") {
                        Picker("匿名身份", selection: $selectedCookieID) {
                            ForEach(identity.cookies) { cookie in
                                Text(cookie.name).tag(Optional(cookie.id))
                            }
                        }
                        if let cookie = identity.cookie(id: selectedCookieID) {
                            LabeledContent("标识", value: cookie.maskedUserHash)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("默认选择发帖主饼干；本次切换不会修改主饼干设置。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Section("正文") {
                    TextField("标题（可选）", text: $title)
                        .textInputAutocapitalization(.sentences)
                    TextEditor(text: $content)
                        .focused($editorFocused)
                        .frame(minHeight: 180)
                        .overlay(alignment: .topLeading) {
                            if content.isEmpty {
                                Text("说点什么…")
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .allowsHitTesting(false)
                            }
                        }
                    Text("\(content.count) 字")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    KaomojiPicker { insertKaomoji($0) }
                }
                Section("附件与署名") {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        if isPreparingImage {
                            Label("正在处理图片…", systemImage: "hourglass")
                        } else {
                            Label(
                                attachment == nil ? "添加图片" : "已选择图片",
                                systemImage: attachment == nil ? "photo.badge.plus" : "photo.fill"
                            )
                        }
                    }
                    .disabled(isPreparingImage || model.isSending)
                    if attachment != nil {
                        Button("移除图片", role: .destructive) {
                            selectedPhoto = nil
                            attachment = nil
                        }
                    }
                    TextField("署名（默认无名氏）", text: $name)
                }
                Section {
                    Text("前台仅展示饼干对应的匿名身份；账号信息不会写入帖子。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }.disabled(model.isSending)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("发送") { Task { await send() } }
                        .fontWeight(.semibold)
                        .disabled(
                            content.nilIfBlank == nil ||
                            identity.cookie(id: selectedCookieID) == nil ||
                            isPreparingImage ||
                            model.isSending
                        )
                }
            }
            .overlay { if model.isSending { SendingOverlay() } }
            .task(id: selectedPhoto) { await prepareSelectedPhoto() }
            .onChange(of: identity.cookies.map(\.id)) {
                if identity.cookie(id: selectedCookieID) == nil {
                    selectedCookieID = identity.postingCookieID
                }
            }
            .onAppear { editorFocused = true }
            .interactiveDismissDisabled(model.isSending)
            .alert("操作失败", isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.clearError() } }
            )) {
                Button("好", role: .cancel) {}
            } message: {
                Text(model.errorMessage ?? "")
            }
        }
    }

    private func prepareSelectedPhoto() async {
        guard let selectedPhoto else {
            attachment = nil
            return
        }
        isPreparingImage = true
        defer { isPreparingImage = false }

        do {
            guard let data = try await selectedPhoto.loadTransferable(type: Data.self) else {
                throw ImagePreparationError.unreadable
            }
            try Task.checkCancellation()
            attachment = try ImageAttachment.preparing(data)
        } catch is CancellationError {
            return
        } catch {
            attachment = nil
            self.selectedPhoto = nil
            model.present(error: error)
        }
    }

    private func insertKaomoji(_ value: String) {
        if let lastCharacter = content.last, !lastCharacter.isWhitespace {
            content.append(" ")
        }
        content.append(value)
        editorFocused = true
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func send() async {
        guard !model.isSending else { return }
        guard let hash = identity.cookie(id: selectedCookieID)?.userHash else {
            model.present(error: APIError.missingIdentity)
            return
        }
        let destination: ComposerDestination
        switch mode {
        case .thread(let forum): destination = .forum(forum.id)
        case .reply(let threadID): destination = .thread(threadID)
        }
        let submission = await model.submit(
            destination: destination,
            draft: ComposerDraft(
                content: content,
                title: title,
                name: name,
                imageData: attachment?.data,
                imageExtension: attachment?.fileExtension
            ),
            userHash: hash
        )
        guard let submission else { return }
        history.record(historyEntry(for: submission))
        dismiss()
        await onSuccess()
    }

    private func historyEntry(for submission: ComposerSubmission) -> PostHistoryEntry {
        let kind: PostHistoryKind
        let forumID: Int?
        let forumName: String?
        switch mode {
        case .thread(let forum):
            kind = .thread
            forumID = forum.id
            forumName = forum.displayName
        case .reply:
            kind = .reply
            forumID = nil
            forumName = nil
        }
        return PostHistoryEntry(
            id: UUID(),
            kind: kind,
            createdAt: Date(),
            threadID: submission.threadID,
            forumID: forumID,
            forumName: forumName,
            title: title,
            content: content,
            authorName: name,
            hasAttachment: attachment != nil
        )
    }
}

private struct ImageAttachment {
    let data: Data
    let fileExtension: String

    private static let maximumBytes = 10 * 1_024 * 1_024
    private static let maximumDimension: CGFloat = 2_400

    static func preparing(_ originalData: Data) throws -> ImageAttachment {
        guard !originalData.isEmpty else { throw ImagePreparationError.unreadable }
        if let fileExtension = originalData.detectedImageExtension,
           originalData.count <= maximumBytes {
            return ImageAttachment(data: originalData, fileExtension: fileExtension)
        }

        if originalData.detectedImageExtension == "gif" {
            throw ImagePreparationError.tooLargeGIF
        }
        guard let originalImage = UIImage(data: originalData) else {
            throw ImagePreparationError.unsupported
        }

        let image = resizedImageIfNeeded(originalImage)
        for quality in [0.82, 0.68, 0.52, 0.38] {
            if let data = image.jpegData(compressionQuality: quality), data.count <= maximumBytes {
                return ImageAttachment(data: data, fileExtension: "jpg")
            }
        }
        throw ImagePreparationError.tooLarge
    }

    private static func resizedImageIfNeeded(_ image: UIImage) -> UIImage {
        let largestDimension = max(image.size.width, image.size.height)
        guard largestDimension > maximumDimension, largestDimension > 0 else { return image }
        let scale = maximumDimension / largestDimension
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

private enum ImagePreparationError: LocalizedError {
    case unreadable
    case unsupported
    case tooLarge
    case tooLargeGIF

    var errorDescription: String? {
        switch self {
        case .unreadable: return "无法读取所选图片，请重新选择"
        case .unsupported: return "图片格式不受支持"
        case .tooLarge: return "图片压缩后仍超过 10 MB"
        case .tooLargeGIF: return "GIF 超过 10 MB，无法在保留动画的情况下上传"
        }
    }
}

private extension Data {
    var detectedImageExtension: String? {
        guard count >= 4 else { return nil }
        let bytes = [UInt8](prefix(4))
        if bytes.starts(with: [0xFF, 0xD8]) { return "jpg" }
        if bytes == [0x89, 0x50, 0x4E, 0x47] { return "png" }
        if String(data: prefix(4), encoding: .ascii) == "GIF8" { return "gif" }
        return nil
    }
}
