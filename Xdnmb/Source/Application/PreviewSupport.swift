//
// PreviewSupport.swift
// Author: Maru
//

import SwiftUI

enum AppRuntimeMode {
    case live
    case preview

    var isPreview: Bool { self == .preview }
}

private struct AppRuntimeModeKey: EnvironmentKey {
    static let defaultValue = AppRuntimeMode.live
}

extension EnvironmentValues {
    var appRuntimeMode: AppRuntimeMode {
        get { self[AppRuntimeModeKey.self] }
        set { self[AppRuntimeModeKey.self] = newValue }
    }
}

enum PreviewFixtures {
    static let feedID = "6d627793-a2c8-4dc6-aa3d-5910766c91ca"
    static let userHash = "preview_cookie_7f4a"

    static let timelines = [
        Timeline(
            id: 1,
            name: "综合时间线",
            displayName: "综合时间线",
            notice: "这里汇集岛上正在发生的讨论。Preview 中的内容完全来自本地。",
            maxPage: 1
        ),
        Timeline(id: 2, name: "欢乐恶搞", displayName: "欢乐恶搞", notice: "轻松交流，友善回复。", maxPage: 1)
    ]

    static let forums = [
        Forum(id: 4, name: "综合版1", message: "日常话题与岛民交流", shownName: "综合版", threadCount: 128, postCount: 3_842),
        Forum(id: 20, name: "欢乐恶搞", message: "分享有趣的图片、段子与脑洞", threadCount: 96, postCount: 2_176),
        Forum(id: 30, name: "技术宅", message: "编程、硬件和数字生活", threadCount: 72, postCount: 1_408),
        Forum(id: 75, name: "料理", message: "家常菜、食谱与深夜食堂", threadCount: 45, postCount: 892)
    ]

    static let forumGroups = [
        ForumCategory(status: "n", id: 1, name: "讨论", sort: 1, forums: Array(forums.prefix(3))),
        ForumCategory(status: "n", id: 2, name: "生活", sort: 2, forums: [forums[3]])
    ]

    static let notice = SiteNotice(
        content: "欢迎使用 Xdnmb。请友善交流，并妥善保管自己的饼干与 Feed ID。",
        date: "2026-07-18",
        enable: true
    )

    static let threads: [ForumThread] = [
        ForumThread(
            post: post(
                id: 69047539,
                forumID: 4,
                replyCount: 3,
                hash: "po_48a1",
                title: "夏日散步记录",
                content: "傍晚的风终于凉下来了。你们最近有什么适合一个人散步的路线吗？"
            ),
            replies: [
                post(id: 69047542, forumID: 4, hash: "reply_a", content: ">>No.69047539\n沿河走很舒服，日落以后灯也很好看。"),
                post(id: 69047558, forumID: 4, hash: "po_48a1", content: "收到，今晚就去试试，谢谢岛民！")
            ],
            remainReplies: 1
        ),
        ForumThread(
            post: post(
                id: 69047408,
                forumID: 30,
                replyCount: 2,
                hash: "tech_09c2",
                title: "第一次写 iOS App",
                content: "SwiftUI 的 Preview 很适合打磨组件。大家会怎样组织示例数据？"
            ),
            replies: [
                post(id: 69047413, forumID: 30, hash: "reply_b", content: "我会把 fixtures 和线上服务分开，预览就不会依赖网络。")
            ],
            remainReplies: 1
        ),
        ForumThread(
            post: post(
                id: 69047261,
                forumID: 75,
                replyCount: 1,
                hash: "cook_1220",
                title: "十分钟夜宵",
                content: "冰箱里只剩鸡蛋和番茄，最后做出来意外地很满足。"
            ),
            replies: [],
            remainReplies: 1
        )
    ]

    static let feedEntries = Array(threads.prefix(2)).map {
        FeedEntry(post: $0.post, recentReplies: $0.replies, category: "订阅")
    }

    static func threadDetail(id: Int, onlyPO: Bool = false) -> ThreadDetail {
        let source = threads.first(where: { $0.id == id }) ?? threads[0]
        let root = Post(
            id: id,
            forumID: source.post.forumID,
            replyCount: source.post.replyCount,
            imagePath: "",
            imageExtension: "",
            createdAt: source.post.createdAt,
            userHash: source.post.userHash,
            name: source.post.name,
            title: source.post.title,
            content: source.post.content,
            sage: false,
            admin: false,
            hidden: false
        )
        let replies = onlyPO ? source.replies.filter { $0.userHash == root.userHash } : source.replies
        return ThreadDetail(post: root, replies: replies)
    }

    private static func post(
        id: Int,
        forumID: Int,
        replyCount: Int = 0,
        hash: String,
        title: String = "",
        content: String
    ) -> Post {
        Post(
            id: id,
            forumID: forumID,
            replyCount: replyCount,
            imagePath: "",
            imageExtension: "",
            createdAt: "2026-07-18 18:24:00",
            userHash: hash,
            name: "无名氏",
            title: title,
            content: content,
            sage: false,
            admin: false,
            hidden: false
        )
    }
}
