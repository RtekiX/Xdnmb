//
// Forum.swift
// Author: Maru
//

import Foundation

struct ForumCategory: Decodable, Identifiable, Hashable, Sendable {
    let status: String
    let id: Int
    let name: String
    let sort: Int
    let forums: [Forum]

    var visibleForums: [Forum] {
        forums.filter(\.isBrowsable)
    }

    enum CodingKeys: String, CodingKey {
        case status, id, name, sort, forums
    }

    init(status: String, id: Int, name: String, sort: Int, forums: [Forum]) {
        self.status = status
        self.id = id
        self.name = name
        self.sort = sort
        self.forums = forums
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.lossyString(forKey: .status)
        id = container.lossyInt(forKey: .id)
        name = container.lossyString(forKey: .name)
        sort = container.lossyInt(forKey: .sort)
        forums = container.lossyArray(Forum.self, forKey: .forums)
    }
}

struct Forum: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let sort: Int?
    let threadCount: Int?
    let postCount: Int?
    let isHidden: Bool?
    let groupID: Int?
    let message: String
    let autoDelete: Int?
    let fuseID: Int?
    let createdAt: String?
    let interval: Int?
    let safeMode: Bool?
    let permissionLevel: Int?
    let status: String?
    let updatedAt: String?
    let shownName: String?

    var displayName: String { shownName?.nilIfBlank ?? name.nilIfBlank ?? "未命名版块" }
    var summary: String { message.htmlPlainText.nilIfBlank ?? "浏览该版块的最新讨论" }
    var isBrowsable: Bool { id > 0 && isHidden != true && status?.lowercased() != "x" }
    var maxPage: Int {
        let pages = ((threadCount ?? 0) + 19) / 20
        return min(max(pages, 1), 100)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, sort, msg, status, interval
        case threadCount = "thread_count"
        case postCount = "post_count"
        case isHidden = "is_hidden"
        case groupID = "fgroup"
        case autoDelete = "auto_delete"
        case fuseID = "forum_fuse_id"
        case createdAt
        case updatedAt = "updateAt"
        case shownName = "showName"
        case safeMode = "safe_mode"
        case permissionLevel = "permission_level"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.lossyInt(forKey: .id)
        name = container.lossyString(forKey: .name)
        sort = container.lossyOptionalInt(forKey: .sort)
        threadCount = container.lossyOptionalInt(forKey: .threadCount)
        postCount = container.lossyOptionalInt(forKey: .postCount)
        isHidden = container.lossyOptionalBool(forKey: .isHidden)
        groupID = container.lossyOptionalInt(forKey: .groupID)
        message = container.lossyString(forKey: .msg)
        autoDelete = container.lossyOptionalInt(forKey: .autoDelete)
        fuseID = container.lossyOptionalInt(forKey: .fuseID)
        createdAt = container.lossyOptionalString(forKey: .createdAt)
        interval = container.lossyOptionalInt(forKey: .interval)
        safeMode = container.lossyOptionalBool(forKey: .safeMode)
        permissionLevel = container.lossyOptionalInt(forKey: .permissionLevel)
        status = container.lossyOptionalString(forKey: .status)
        updatedAt = container.lossyOptionalString(forKey: .updatedAt)
        shownName = container.lossyOptionalString(forKey: .shownName)
    }
}

struct Timeline: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let displayName: String
    let notice: String
    let maxPage: Int

    enum CodingKeys: String, CodingKey {
        case id, name, notice
        case displayName = "display_name"
        case maxPage = "max_page"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.lossyInt(forKey: .id)
        name = container.lossyString(forKey: .name)
        displayName = container.lossyString(forKey: .displayName).nilIfBlank ?? name
        notice = container.lossyString(forKey: .notice)
        maxPage = min(max(container.lossyInt(forKey: .maxPage), 1), 1_000)
    }
}

struct SiteNotice: Decodable, Hashable, Sendable {
    let content: String
    let date: String
    let enable: Bool

    enum CodingKeys: CodingKey {
        case content, date, enable
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        content = container.lossyString(forKey: .content)
        date = container.lossyString(forKey: .date)
        enable = container.lossyOptionalBool(forKey: .enable) ?? false
    }
}
