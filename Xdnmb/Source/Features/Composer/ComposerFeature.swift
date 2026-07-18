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

    @Environment(\.dismiss) private var dismiss
    @State private var content = ""
    @State private var title = ""
    @State private var name = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var attachment: ImageAttachment?
    @State private var isPreparingImage = false
    @State private var isSending = false
    @State private var errorMessage: String?
    @FocusState private var editorFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                if !identity.hasIdentity {
                    Section {
                        Label("请先在“我的”中导入 userhash 饼干", systemImage: "exclamationmark.shield")
                            .foregroundStyle(.orange)
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
                    .disabled(isPreparingImage || isSending)
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
                    Button("取消") { dismiss() }.disabled(isSending)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("发送") { Task { await send() } }
                        .fontWeight(.semibold)
                        .disabled(
                            content.nilIfBlank == nil ||
                            !identity.hasIdentity ||
                            isPreparingImage ||
                            isSending
                        )
                }
            }
            .overlay { if isSending { SendingOverlay() } }
            .task(id: selectedPhoto) { await prepareSelectedPhoto() }
            .onAppear { editorFocused = true }
            .interactiveDismissDisabled(isSending)
            .alert("操作失败", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("好", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
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
            errorMessage = error.localizedDescription
        }
    }

    private func send() async {
        guard !isSending else { return }
        guard let hash = identity.userHash.nilIfBlank else {
            errorMessage = APIError.missingIdentity.localizedDescription
            return
        }
        isSending = true
        defer { isSending = false }

        do {
            switch mode {
            case .thread(let forum):
                try await APIService.shared.createThread(
                    forumID: forum.id,
                    content: content,
                    title: title,
                    name: name,
                    imageData: attachment?.data,
                    imageExtension: attachment?.fileExtension,
                    userHash: hash
                )
            case .reply(let threadID):
                try await APIService.shared.reply(
                    threadID: threadID,
                    content: content,
                    title: title,
                    name: name,
                    imageData: attachment?.data,
                    imageExtension: attachment?.fileExtension,
                    userHash: hash
                )
            }
            dismiss()
            await onSuccess()
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
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
