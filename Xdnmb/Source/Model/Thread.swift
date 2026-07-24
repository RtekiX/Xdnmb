//
// Thread.swift
// Author: Maru
//

import Foundation

struct Post: Decodable, Hashable, Sendable {
    let id: Int
    let forumID: Int
    let replyCount: Int
    let imagePath: String
    let imageExtension: String
    let createdAt: String
    let userHash: String
    let name: String
    let title: String
    let content: String
    let sage: Bool
    let admin: Bool
    let hidden: Bool

    var displayName: String { name.nilIfBlank ?? "无名氏" }
    var displayTitle: String? {
        guard let value = title.nilIfBlank, value != "无标题" else { return nil }
        return value
    }
    var plainContent: String { content.htmlPlainText }
    var hasImage: Bool { imagePath.nilIfBlank != nil && imageExtension.nilIfBlank != nil }

    enum CodingKeys: String, CodingKey {
        case id, fid, img, ext, now, name, title, content, sage, admin
        case replyCount = "ReplyCount"
        case userHash = "user_hash"
        case hidden = "Hide"
    }

    init(id: Int, forumID: Int, replyCount: Int, imagePath: String, imageExtension: String,
         createdAt: String, userHash: String, name: String, title: String, content: String,
         sage: Bool, admin: Bool, hidden: Bool) {
        self.id = id
        self.forumID = forumID
        self.replyCount = max(replyCount, 0)
        self.imagePath = imagePath
        self.imageExtension = imageExtension
        self.createdAt = createdAt
        self.userHash = userHash
        self.name = name
        self.title = title
        self.content = content
        self.sage = sage
        self.admin = admin
        self.hidden = hidden
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: container.lossyInt(forKey: .id),
            forumID: container.lossyInt(forKey: .fid),
            replyCount: container.lossyInt(forKey: .replyCount),
            imagePath: container.lossyString(forKey: .img),
            imageExtension: container.lossyString(forKey: .ext),
            createdAt: container.lossyString(forKey: .now),
            userHash: container.lossyString(forKey: .userHash),
            name: container.lossyString(forKey: .name),
            title: container.lossyString(forKey: .title),
            content: container.lossyString(forKey: .content),
            sage: container.lossyBool(forKey: .sage),
            admin: container.lossyBool(forKey: .admin),
            hidden: container.lossyBool(forKey: .hidden)
        )
    }
}

struct ForumThread: Decodable, Identifiable, Hashable, Sendable {
    let post: Post
    let replies: [Post]
    let remainReplies: Int

    var id: Int { post.id }

    enum CodingKeys: String, CodingKey {
        case replies = "Replies"
        case remainReplies = "RemainReplies"
    }

    init(post: Post, replies: [Post], remainReplies: Int) {
        self.post = post
        self.replies = replies
        self.remainReplies = max(remainReplies, 0)
    }

    init(from decoder: Decoder) throws {
        post = try Post(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        replies = container.lossyArray(Post.self, forKey: .replies)
        remainReplies = max(container.lossyInt(forKey: .remainReplies), 0)
    }
}

struct ThreadDetail: Decodable, Identifiable, Hashable, Sendable {
    let post: Post
    let replies: [Post]

    var id: Int { post.id }
    var maxPage: Int {
        min(max((post.replyCount + 18) / 19, 1), 1_000)
    }

    enum CodingKeys: String, CodingKey {
        case replies = "Replies"
    }

    init(post: Post, replies: [Post]) {
        self.post = post
        self.replies = replies
    }

    init(from decoder: Decoder) throws {
        post = try Post(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        replies = container.lossyArray(Post.self, forKey: .replies)
    }
}

struct LastPost: Decodable, Hashable, Sendable {
    let parentThreadID: Int
    let id: Int
    let content: String

    var threadID: Int { parentThreadID > 0 ? parentThreadID : id }

    enum CodingKeys: String, CodingKey {
        case parentThreadID = "resto"
        case id, content
    }

    init(parentThreadID: Int, id: Int, content: String) {
        self.parentThreadID = parentThreadID
        self.id = id
        self.content = content
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        parentThreadID = container.lossyInt(forKey: .parentThreadID)
        id = container.lossyInt(forKey: .id)
        content = container.lossyString(forKey: .content)
    }
}

struct FeedEntry: Decodable, Identifiable, Hashable, Sendable {
    let post: Post
    let recentReplies: [Post]
    let category: String

    var id: Int { post.id }

    enum CodingKeys: String, CodingKey {
        case id, fid, img, ext, now, name, title, content, admin, category, sage
        case replyCount = "reply_count"
        case userHash = "user_hash"
        case recentReplies = "recent_replies"
        case hidden = "hide"
    }

    init(post: Post, recentReplies: [Post], category: String) {
        self.post = post
        self.recentReplies = recentReplies
        self.category = category
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        post = Post(
            id: container.lossyInt(forKey: .id),
            forumID: container.lossyInt(forKey: .fid),
            replyCount: container.lossyInt(forKey: .replyCount),
            imagePath: container.lossyString(forKey: .img),
            imageExtension: container.lossyString(forKey: .ext),
            createdAt: container.lossyString(forKey: .now),
            userHash: container.lossyString(forKey: .userHash),
            name: container.lossyString(forKey: .name),
            title: container.lossyString(forKey: .title),
            content: container.lossyString(forKey: .content),
            sage: container.lossyBool(forKey: .sage),
            admin: container.lossyBool(forKey: .admin),
            hidden: container.lossyBool(forKey: .hidden)
        )
        recentReplies = container.lossyArray(Post.self, forKey: .recentReplies)
        category = container.lossyString(forKey: .category)
    }
}

extension ForumThread {
    init(feedEntry: FeedEntry) {
        self.init(
            post: feedEntry.post,
            replies: feedEntry.recentReplies,
            remainReplies: feedEntry.post.replyCount - feedEntry.recentReplies.count
        )
    }
}
