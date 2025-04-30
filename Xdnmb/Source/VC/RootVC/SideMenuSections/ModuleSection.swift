//
//  ModuleSection.swift
//  Xdnmb
//
//  Created by Yuno's on 2025/5/7.
//

import UIKit
import Foundation

class ModuleSection: SectionManagable {
    private weak var collectionView: UICollectionView?

    init(with collectionView: UICollectionView) {
        self.collectionView = collectionView
    }

    func numberOfItems() -> Int {
        return 10
    }

    func cellForItem(at index: Int) -> UICollectionViewCell {
        if let cell = collectionView?.dequeueReusableCell(withReuseIdentifier: "moduleCell", for: IndexPath(item: index, section: 0)) as? ModuleCell {
            return cell
        }
        return UICollectionViewCell()
    }

    func sizeForItem(at index: Int) -> CGSize {
        return CGSize(width: self.collectionView?.frame.width ?? 0, height: 100)  
    }

    func didSelectItem(at index: Int) {
        print("didSelectItem: \(index)")
    }

    var cellClass: UICollectionViewCell.Type {
        return ModuleCell.self
    }

    var cellIdentifier: String {
        return "moduleCell"
    }
}

extension ModuleSection {
    class ModuleCell: UICollectionViewCell {
        private lazy var title: UILabel = {
            let label = UILabel()
            label.textAlignment = .center
            label.font = UIFont.systemFont(ofSize: 16)
            label.textColor = .white
            return label
        }()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            contentView.addSubview(title)
            contentView.backgroundColor = .green
            title.snp.makeConstraints { make in
                make.center.equalToSuperview()
            }
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}
