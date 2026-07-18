//
// RemoteImage.swift
// Author: Maru
//

import SwiftUI

struct RemoteImage: View {
    let url: URL
    let maxHeight: CGFloat
    var viewerURL: URL?

    @State private var showingViewer = false

    init(url: URL, maxHeight: CGFloat, viewerURL: URL? = nil) {
        self.url = url
        self.maxHeight = maxHeight
        self.viewerURL = viewerURL
    }

    var body: some View {
        Button { showingViewer = true } label: {
            AsyncImage(url: url, transaction: Transaction(animation: .easeInOut)) { phase in
                switch phase {
                case .empty:
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.quaternary)
                        .overlay { ProgressView() }
                        .frame(height: 160)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: maxHeight)
                        .clipShape(.rect(cornerRadius: 12))
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.caption.weight(.semibold))
                                .padding(8)
                                .foregroundStyle(.white)
                                .background(.black.opacity(0.55), in: .circle)
                                .padding(8)
                        }
                case .failure:
                    Label("图片加载失败", systemImage: "photo.badge.exclamationmark")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 100)
                        .background(.quaternary, in: .rect(cornerRadius: 12))
                @unknown default:
                    EmptyView()
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("帖子图片")
        .accessibilityHint("打开大图查看器")
        .fullScreenCover(isPresented: $showingViewer) {
            ImageViewer(url: viewerURL ?? url)
        }
    }
}
