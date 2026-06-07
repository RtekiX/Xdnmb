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
    let type: SettingItemType

    init(title: String, image: UIImage?, type: SettingItemType) {
        self.title = title
        self.image = image
        self.type = type
    }
}

enum SettingItemType: Int, CaseIterable {
    case collection = 0
    case history
    case reply
}
