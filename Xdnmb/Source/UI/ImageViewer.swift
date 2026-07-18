//
// ImageViewer.swift
// Author: Maru
//

import Combine
import Photos
import SwiftUI
import UIKit

@MainActor
private final class ImageViewerModel: ObservableObject {
    @Published private(set) var image: UIImage?
    @Published private(set) var isLoading = true
    @Published private(set) var isSaving = false
    @Published var message: String?

    func load(from url: URL) async {
        guard image == nil else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let response = response as? HTTPURLResponse,
                  (200..<300).contains(response.statusCode),
                  let image = UIImage(data: data) else {
                throw ImageViewerError.invalidImage
            }
            self.image = image
        } catch is CancellationError {
            return
        } catch {
            message = error.localizedDescription
        }
    }

    func saveToPhotoLibrary() async {
        guard let image, !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        let authorization = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard authorization == .authorized || authorization == .limited else {
            message = ImageViewerError.photoAccessDenied.localizedDescription
            return
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            message = "图片已保存到照片"
        } catch {
            message = ImageViewerError.saveFailed.localizedDescription
        }
    }
}

struct ImageViewer: View {
    let url: URL

    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = ImageViewerModel()
    @State private var scale: CGFloat = 1
    @State private var settledScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var settledOffset: CGSize = .zero

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if let image = model.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(offset)
                        .contentShape(.rect)
                        .gesture(magnificationGesture)
                        .simultaneousGesture(dragGesture)
                        .onTapGesture(count: 2) { toggleZoom() }
                        .accessibilityLabel("大图")
                        .accessibilityHint("双击可放大或还原")
                } else if model.isLoading {
                    ProgressView("正在加载原图…")
                        .tint(.white)
                        .foregroundStyle(.white)
                } else {
                    ContentUnavailableView(
                        "图片加载失败",
                        systemImage: "photo.badge.exclamationmark",
                        description: Text("请检查网络后重试")
                    )
                    .foregroundStyle(.white)
                }
            }
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await model.saveToPhotoLibrary() }
                    } label: {
                        if model.isSaving {
                            ProgressView()
                        } else {
                            Label("保存图片", systemImage: "square.and.arrow.down")
                        }
                    }
                    .disabled(model.image == nil || model.isSaving)
                }
            }
        }
        .task { await model.load(from: url) }
        .alert("图片", isPresented: Binding(
            get: { model.message != nil },
            set: { if !$0 { model.message = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(model.message ?? "")
        }
    }

    private var magnificationGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = min(max(settledScale * value.magnification, 1), 5)
                if scale == 1 { offset = .zero }
            }
            .onEnded { _ in
                settledScale = scale
                if scale == 1 {
                    offset = .zero
                    settledOffset = .zero
                }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > 1 else { return }
                offset = CGSize(
                    width: settledOffset.width + value.translation.width,
                    height: settledOffset.height + value.translation.height
                )
            }
            .onEnded { _ in settledOffset = offset }
    }

    private func toggleZoom() {
        withAnimation(.snappy) {
            if scale > 1 {
                scale = 1
                settledScale = 1
                offset = .zero
                settledOffset = .zero
            } else {
                scale = 2.5
                settledScale = 2.5
            }
        }
    }
}

private enum ImageViewerError: LocalizedError {
    case invalidImage
    case photoAccessDenied
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "服务器返回的图片无法识别"
        case .photoAccessDenied: return "请在系统设置中允许 Xdnmb 添加照片"
        case .saveFailed: return "图片保存失败，请稍后重试"
        }
    }
}
