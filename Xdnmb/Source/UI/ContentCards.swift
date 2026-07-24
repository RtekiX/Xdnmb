//
// ContentCards.swift
// Author: Maru
//

import SwiftUI

struct ThreadCard: View {
    let thread: ForumThread

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PostHeader(post: thread.post, showsNumber: true)
            if let title = thread.post.displayTitle {
                Text(title).font(.headline).foregroundStyle(.primary)
            }
            if thread.post.hidden {
                Label("内容已被隐藏", systemImage: "eye.slash")
                    .font(.body)
                    .foregroundStyle(.secondary)
            } else {
                Text(thread.post.plainContent.nilIfBlank ?? "（无正文）")
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
                if let url = APIService.imageURL(
                    path: thread.post.imagePath,
                    extension: thread.post.imageExtension
                ) {
                    RemoteImage(
                        url: url,
                        maxHeight: 190,
                        viewerURL: APIService.imageURL(
                            path: thread.post.imagePath,
                            extension: thread.post.imageExtension,
                            original: true
                        )
                    )
                }
            }
            if let reply = thread.replies.last {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "arrowshape.turn.up.left.fill")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text(reply.hidden ? "内容已被隐藏" : (reply.plainContent.nilIfBlank ?? "（无正文）"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .tertiarySystemBackground), in: .rect(cornerRadius: 10))
            }
            HStack {
                Label("\(thread.post.replyCount)", systemImage: "bubble.left")
                if thread.remainReplies > 0 { Text("另有 \(thread.remainReplies) 条回复") }
                Spacer()
                Image(systemName: "chevron.right").font(.caption.weight(.semibold))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(AppTheme.elevated, in: .rect(cornerRadius: 14))
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityHint("打开帖子详情")
    }
}

struct PostCard: View {
    let post: Post
    let isOriginalPoster: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PostHeader(post: post, showsNumber: true, isOriginalPoster: isOriginalPoster)
            if let title = post.displayTitle { Text(title).font(.headline) }
            if post.hidden {
                Label("内容已被隐藏", systemImage: "eye.slash")
                    .foregroundStyle(.secondary)
            } else {
                Text(post.plainContent.nilIfBlank ?? "（无正文）")
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let url = APIService.imageURL(
                    path: post.imagePath,
                    extension: post.imageExtension,
                    original: true
                ) {
                    RemoteImage(url: url, maxHeight: 460, viewerURL: url)
                }
            }
            if post.sage {
                Label("SAGE", systemImage: "leaf")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(AppTheme.elevated, in: .rect(cornerRadius: 14))
    }
}

struct PostHeader: View {
    let post: Post
    var showsNumber = false
    var isOriginalPoster = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(post.displayName)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            if isOriginalPoster { Text("PO").badgeStyle(color: AppTheme.accent) }
            if post.admin { Text("管理").badgeStyle(color: .red) }
            if let createdAt = post.createdAt.nilIfBlank {
                Text(createdAt)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            if showsNumber, post.id > 0 {
                Text("No.\(post.id)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }
}

struct BoardRow: View {
    let forum: Forum

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "text.bubble")
                .foregroundStyle(AppTheme.accent)
                .frame(width: 28, height: 28)
            Text(forum.displayName)
                .font(.body.weight(.medium))
        }
        .padding(.vertical, 2)
    }
}

struct NoticeCard: View {
    let notice: SiteNotice

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("站点公告", systemImage: "megaphone.fill")
                .font(.headline)
                .foregroundStyle(AppTheme.accent)
            Text(notice.content.htmlPlainText).font(.subheadline).lineLimit(6)
            if let date = notice.date.nilIfBlank {
                Text(date).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.accent.opacity(0.1), in: .rect(cornerRadius: 18))
    }
}

struct PinnedNoticeThreadCard: View {
    let title: String
    let content: String
    var date: String? = nil
    var symbol = "megaphone.fill"

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "pin.fill")
                Text("置顶")
                    .fontWeight(.bold)
                Text("公告串")
                Spacer()
                if let date = date?.nilIfBlank {
                    Text(date)
                        .lineLimit(1)
                }
            }
            .font(.caption)
            .foregroundStyle(AppTheme.accent)
            Label(title, systemImage: symbol)
                .font(.headline)
                .foregroundStyle(.primary)
            Text(content.htmlPlainText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            HStack {
                Text("查看完整公告")
                Spacer()
                Image(systemName: "chevron.right")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(AppTheme.elevated, in: .rect(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppTheme.accent.opacity(0.28), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("打开完整公告")
    }
}

struct NoticeDetailScreen: View {
    let title: String
    let content: String
    var date: String? = nil
    var source = "X 岛公告"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Label(source, systemImage: "pin.fill")
                        .font(.headline)
                        .foregroundStyle(AppTheme.accent)
                    Spacer()
                    if let date = date?.nilIfBlank {
                        Text(date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(title)
                    .font(.title2.bold())
                Text(content.htmlPlainText)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)
            .background(AppTheme.elevated, in: .rect(cornerRadius: 18))
            .padding(16)
        }
        .background(AppTheme.groupedBackground)
        .navigationTitle("公告")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension View {
    func badgeStyle(color: Color) -> some View {
        font(.caption2.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.12), in: .capsule)
    }
}
