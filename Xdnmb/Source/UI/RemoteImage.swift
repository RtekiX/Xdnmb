//
// RemoteImage.swift
// Author: Maru
//

import SwiftUI

struct RemoteImage: View {
    let url: URL
    let maxHeight: CGFloat

    var body: some View {
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
            case .failure:
                Label("图片加载失败", systemImage: "photo.badge.exclamationmark")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 100)
                    .background(.quaternary, in: .rect(cornerRadius: 12))
            @unknown default:
                EmptyView()
            }
        }
        .accessibilityLabel("帖子图片")
    }
}
