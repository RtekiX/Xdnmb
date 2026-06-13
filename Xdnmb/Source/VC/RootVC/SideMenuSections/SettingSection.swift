//
//  SettingSection.swift
//  Xdnmb
//
//  Created by Yuno's on 2025/5/7.
//

import UIKit
import Foundation
import SnapKit

class SettingSection: SectionManagable {
    private weak var collectionView: UICollectionView?
    private var settingItemModels: [SettingItemModel] = []

    init(with collectionView: UICollectionView) {
        self.collectionView = collectionView
        setupSettingItemModels()
    }

    private func setupSettingItemModels() {
        settingItemModels = [
            SettingItemModel(title: "收藏", image: UIImage(systemName: "star"), type: .collection),
            SettingItemModel(title: "历史", image: UIImage(systemName: "clock"), type: .history),
            SettingItemModel(title: "回复", image: UIImage(systemName: "arrowshape.turn.up.left"), type: .reply)
        ]
    }

    func numberOfItems() -> Int {
        return 1
    }

    func cellForItem(at index: Int) -> UICollectionViewCell {
        if let cell = collectionView?.dequeueReusableCell(withReuseIdentifier: "settingCell", for: IndexPath(item: index, section: 0)) as? SettingCell {
            cell.update(with: settingItemModels)
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
            collectionView.alwaysBounceHorizontal = false
            return collectionView
        }()
        
        private var settingItemModels: [SettingItemModel] = []
        
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

        func update(with settingItemModels: [SettingItemModel]) {
            self.settingItemModels = settingItemModels
            innerCollectionView.reloadData()
        }
        
        func numberOfSections(in collectionView: UICollectionView) -> Int {
            return 1
        }
        
        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            return settingItemModels.count
        }

        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            if let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "settingItemCell", for: indexPath) as? SettingItemCell, let model = safeModel(at: indexPath) {
                cell.update(with: model)
                return cell
            }
            return UICollectionViewCell()
        }

        func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
            return CGSize(width: 80, height: 80)
        }
        
        func safeModel(at indexPath: IndexPath) -> SettingItemModel? {
            guard indexPath.row >= 0, indexPath.row < self.settingItemModels.count else {
                return nil
            }
            return self.settingItemModels[indexPath.row]
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

        private lazy var imageView: UIImageView = {
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFit
            return imageView
        }()

        override init(frame: CGRect) {
            super.init(frame: frame)
            contentView.addSubview(title)
            contentView.addSubview(imageView)
            contentView.backgroundColor = .red
            imageView.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(10)
                make.centerX.equalToSuperview()
                make.bottom.lessThanOrEqualTo(title.snp.top).offset(-10)
                make.width.height.equalTo(36)
            }

            title.snp.makeConstraints { make in
                make.centerX.equalToSuperview()
                make.bottom.equalToSuperview().offset(-10)
            }
        }

        func update(with settingItemModel: SettingItemModel) {
            title.text = settingItemModel.title
            imageView.image = settingItemModel.image
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}
