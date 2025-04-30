//
//  SettingSection.swift
//  Xdnmb
//
//  Created by Yuno's on 2025/5/7.
//

import UIKit
import Foundation

class SettingSection: SectionManagable {
    private weak var collectionView: UICollectionView?

    init(with collectionView: UICollectionView) {
        self.collectionView = collectionView
    }

    func numberOfItems() -> Int {
        return 1
    }

    func cellForItem(at index: Int) -> UICollectionViewCell {
        if let cell = collectionView?.dequeueReusableCell(withReuseIdentifier: "settingCell", for: IndexPath(item: index, section: 0)) as? SettingCell {
            return cell
        }
        return UICollectionViewCell()
    }

    func sizeForItem(at index: Int) -> CGSize {
        return CGSize(width: collectionView?.frame.width ?? 0, height: 80)
    }

    func didSelectItem(at index: Int) {
        print("didSelectItem: \(index)")
    }

    var cellClass: UICollectionViewCell.Type {
        return SettingCell.self
    }

    var cellIdentifier: String {
        return "settingCell"
    }
}

extension SettingSection {
    class SettingCell: UICollectionViewCell, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
        private lazy var innerCollectionView: UICollectionView = {
            let layout = UICollectionViewFlowLayout()
            layout.scrollDirection = .horizontal
            let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
            collectionView.delegate = self
            collectionView.dataSource = self
            collectionView.register(SettingItemCell.self, forCellWithReuseIdentifier: "settingItemCell")
            collectionView.backgroundColor = .clear
            collectionView.contentInsetAdjustmentBehavior = .always
            collectionView.showsHorizontalScrollIndicator = false
            collectionView.alwaysBounceHorizontal = true
            return collectionView
        }()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            contentView.addSubview(innerCollectionView)
            innerCollectionView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func numberOfSections(in collectionView: UICollectionView) -> Int {
            return 1
        }
        
        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            return 4
        }

        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            if let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "settingItemCell", for: indexPath) as? SettingItemCell {
                return cell
            }
            return UICollectionViewCell()
        }

        func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
            return CGSize(width: 80, height: 80)
        }
    }

    class SettingItemCell: UICollectionViewCell {
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
            contentView.backgroundColor = .red
            title.snp.makeConstraints { make in
                make.center.equalToSuperview()
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}
