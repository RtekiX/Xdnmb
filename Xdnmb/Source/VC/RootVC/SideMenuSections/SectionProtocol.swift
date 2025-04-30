//
//  SectionProtocol.swift
//  Xdnmb
//
//  Created by Yuno's on 2025/5/7.
//

import UIKit
import Foundation

protocol SectionManagable {
    func numberOfItems() -> Int
    func cellForItem(at index: Int) -> UICollectionViewCell
    func sizeForItem(at index: Int) -> CGSize
    func didSelectItem(at index: Int)
    var cellClass: UICollectionViewCell.Type { get }
    var cellIdentifier: String { get }
}
