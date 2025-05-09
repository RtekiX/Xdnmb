// Thread.swift
// Xdnmb
// 
// Created by Yuno's on 2025/05/07.
// 

import UIKit
import Foundation

struct ThreadItem: Decodable {
    let id: String
    let authorName: String?
    let time: String?
    let title: String?
    let thumbnailImage: UIImage?

    enum CodingKeys: String, CodingKey {
        case id
        case authorName = "author_name"
        case time
        case title
        case thumbnailImage = "thumbnail_image"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        authorName = try container.decodeIfPresent(String.self, forKey: .authorName)
        time = try container.decodeIfPresent(String.self, forKey: .time)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        thumbnailImage = nil
    }
}
