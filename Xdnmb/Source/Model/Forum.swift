//
//  Forum.swift
//  Xdnmb
//
//  Created by Yuno's on 2025/5/7.
//

import Foundation
import UIKit

struct ForumCategory: Decodable {
    let status: String
    let id: String
    let name: String
    let sort: String
    let forums: [Forum]
    
    enum CodingKeys: String, CodingKey {
        case status
        case id
        case name
        case sort
        case forums
    }
}

struct Forum: Decodable {
    let id: String
    let name: String
    let sort: String?
    let threadCount: String?
    let postCount: String?
    let isHidden: Bool?
    let fgroup: String?
    let msg: String
    let autoDelete: String?
    let forumFuseId: String?
    let createdAt: String?
    let interval: String?
    let safeMode: String?
    let permissionLevel: String?
    let status: String?
    let updateAt: String?
    let showName: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case sort
        case threadCount = "thread_count"
        case postCount = "post_count"
        case isHidden = "is_hidden"
        case fgroup
        case msg
        case autoDelete = "auto_delete"
        case forumFuseId = "forum_fuse_id"
        case createdAt = "createdAt"
        case interval
        case safeMode = "safe_mode"
        case permissionLevel = "permission_level"
        case status
        case updateAt = "updateAt"
        case showName = "showName"
    }
} 
