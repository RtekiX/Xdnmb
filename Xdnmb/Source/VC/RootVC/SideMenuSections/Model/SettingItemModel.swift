//  SettingItemModel.swift
//  Xdnmb
//
//  Created by Yuno's on 2025/5/7.
//

import UIKit
import Foundation

struct SettingItemModel {
    let title: String
    let image: UIImage?
    let index: Int
    var type: SettingItemType {
        return SettingItemType(rawValue: index) ?? .collection
    }

    init(title: String, image: UIImage?, index: Int) {
        self.title = title
        self.image = image
        self.index = index
    }
}

enum SettingItemType: Int, CaseIterable {
    case collection = 0
    case history
    case reply
}
