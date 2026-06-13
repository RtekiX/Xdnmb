//
//  BannerSection.swift
//  Xdnmb
//
//  Created by Yuno's on 2025/5/7.
//

import UIKit
import Foundation
import SnapKit

class BannerSection: SectionManagable {
    private weak var collectionView: UICollectionView?

    init(with collectionView: UICollectionView) {
        self.collectionView = collectionView
    }

    func numberOfItems() -> Int {
        return 1
    }

    func cellForItem(at index: Int) -> UICollectionViewCell {
        if let cell = collectionView?.dequeueReusableCell(withReuseIdentifier: "bannerCell", for: IndexPath(item: index, section: 0)) as? BannerCell {
            return cell
        }
        return UICollectionViewCell()
    }

    func sizeForItem(at index: Int) -> CGSize {
        return CGSize(width: collectionView?.frame.width ?? 0, height: 200)
    }

    func didSelectItem(at index: Int) {
        print("didSelectItem: \(index)")
    }

    var cellClass: UICollectionViewCell.Type {
        return BannerCell.self
    }

    var cellIdentifier: String {
        return "bannerCell"
    }
}

extension BannerSection {
    class BannerCell: UICollectionViewCell {
        private lazy var title: UILabel = {
            let label = UILabel()
            label.textAlignment = .center
            label.font = UIFont.systemFont(ofSize: 16)
            label.textColor = .white
            label.text = "X岛"
            return label
        }()

        override init(frame: CGRect) {
            super.init(frame: frame)
            contentView.backgroundColor = .blue
            contentView.addSubview(title)
            title.snp.makeConstraints { make in
                make.bottom.equalToSuperview().offset(-10)
                make.left.equalToSuperview().offset(10)
            }
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}
