//
//  ModuleSection.swift
//  Xdnmb
//
//  Created by Yuno's on 2025/5/7.
//

import UIKit
import Foundation
import SnapKit

class ModuleSection: SectionManagable {
    private weak var collectionView: UICollectionView?
    
    private var currentExpandIndex: Int = 0

    private var isExpanding: Bool {
        return currentExpandIndex >= 0
    }

    init(with collectionView: UICollectionView) {
        self.collectionView = collectionView
        registerCells()
        loadData()
    }

    private func registerCells() {
        collectionView?.register(ModuleCell.self, forCellWithReuseIdentifier: "moduleCell")
        collectionView?.register(SubModuleCell.self, forCellWithReuseIdentifier: "subModuleCell")
    }

    private var forumCategories: [ForumCategory] = []

    func loadData() {
        APIManager.shared.getForumCategories(completion: { [weak self] response in
            guard let self = self else {
                return
            }
            switch response {
            case .success(let value):
                self.forumCategories = value
                self.collectionView?.reloadData()
            case .failure(let error):
                print("114514 \(error.localizedDescription)")
            }
        })
    }

    func numberOfItems() -> Int {
        var count = forumCategories.count
        if isExpanding, currentExpandIndex >= 0, currentExpandIndex < forumCategories.count {
            // 在展开的cell后插入子论坛
            count += forumCategories[currentExpandIndex].forums.count
        }
        return count
    }

    func cellForItem(at index: Int) -> UICollectionViewCell {
        if isExpanding {
            if index < currentExpandIndex {
                if let item: ForumCategory = self.forumCategories[safe: index],
                   let cell = collectionView?.dequeueReusableCell(withReuseIdentifier: "moduleCell", for: IndexPath(item: index, section: 0)) as? ModuleCell {
                    cell.bindData(with: item)
                    cell.isExpanded = false
                    return cell
                }
            } else if index == currentExpandIndex {
                // 展开的cell本身
                if let item: ForumCategory = self.forumCategories[safe: index],
                   let cell = collectionView?.dequeueReusableCell(withReuseIdentifier: "moduleCell", for: IndexPath(item: index, section: 0)) as? ModuleCell {
                    cell.bindData(with: item)
                    cell.isExpanded = true
                    return cell
                }
            } else if index > currentExpandIndex && index <= currentExpandIndex + forumCategories[currentExpandIndex].forums.count {
                // 子论坛cell
                let subIndex = index - currentExpandIndex - 1
                if let forum: Forum = forumCategories[currentExpandIndex].forums[safe: subIndex],
                   let cell = collectionView?.dequeueReusableCell(withReuseIdentifier: "subModuleCell", for: IndexPath(item: index, section: 0)) as? SubModuleCell {
                    cell.bindData(with: forum)
                    return cell
                }
            } else {
                // 展开cell后面的主分类cell
                let actualIndex = index - forumCategories[currentExpandIndex].forums.count
                if let item: ForumCategory = self.forumCategories[safe: actualIndex],
                   let cell = collectionView?.dequeueReusableCell(withReuseIdentifier: "moduleCell", for: IndexPath(item: index, section: 0)) as? ModuleCell {
                    cell.bindData(with: item)
                    cell.isExpanded = false
                    return cell
                }
            }
        } else {
            // 未展开状态，直接显示主分类
            if let item: ForumCategory = self.forumCategories[safe: index],
               let cell = collectionView?.dequeueReusableCell(withReuseIdentifier: "moduleCell", for: IndexPath(item: index, section: 0)) as? ModuleCell {
                cell.bindData(with: item)
                cell.isExpanded = false
                return cell
            }
        }
        
        return UICollectionViewCell()
    }

    func sizeForItem(at index: Int) -> CGSize {
        if isExpanding && index > currentExpandIndex {
            return CGSize(width: self.collectionView?.frame.width ?? 0, height: 60)
        }
        return CGSize(width: self.collectionView?.frame.width ?? 0, height: 100)
    }

    func didSelectItem(at index: Int) {
        if isExpanding {
            if index < currentExpandIndex {
                // 点击主分类
                expand(at: index)   
            } else if index == currentExpandIndex {
                // 点击展开的cell
                collapse()
            } else if index > currentExpandIndex && index <= currentExpandIndex + forumCategories[currentExpandIndex].forums.count {
                // 点击子论坛
                let subIndex = index - currentExpandIndex - 1
                if let forum: Forum = forumCategories[currentExpandIndex].forums[safe: subIndex] {
                    // TODO: 跳转到对应版面
                    
                }
            } else {
                // 点击主分类
                let actualIndex = index - forumCategories[currentExpandIndex].forums.count
                expand(at: actualIndex)
            }
        } else {
            // 未展开状态
            expand(at: index)
        }
    }

    var cellClass: UICollectionViewCell.Type {
        return ModuleCell.self
    }

    var cellIdentifier: String {
        return "moduleCell"
    }
}

extension ModuleSection {
    func expand(at index: Int) {
        currentExpandIndex = index
        collectionView?.reloadData()
    }

    func collapse() {
        currentExpandIndex = -1
        collectionView?.reloadData()
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
        
        private lazy var expandIndicator: UIImageView = {
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFit
            imageView.tintColor = .white
            if let image = UIImage(systemName: "chevron.right") {
                imageView.image = image
            }
            return imageView
        }()
        
        var isExpanded: Bool = false {
            didSet {
                expandIndicator.transform = isExpanded ? CGAffineTransform(rotationAngle: .pi/2) : .identity
            }
        }
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            setupUI()
        }
        
        private func setupUI() {
            contentView.addSubview(title)
            contentView.addSubview(expandIndicator)
            contentView.backgroundColor = .green
            
            title.snp.makeConstraints { make in
                make.centerY.equalToSuperview()
                make.left.equalToSuperview().offset(20)
            }
            
            expandIndicator.snp.makeConstraints { make in
                make.centerY.equalToSuperview()
                make.right.equalToSuperview().offset(-20)
                make.width.height.equalTo(20)
            }
        }
        
        func bindData(with item: ForumCategory?) {
            title.text = item?.name ?? ""
            expandIndicator.isHidden = item == nil
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    class SubModuleCell: UICollectionViewCell {
        private lazy var title: UILabel = {
            let label = UILabel()
            label.textAlignment = .left
            label.font = UIFont.systemFont(ofSize: 14)
            label.textColor = .white
            return label
        }()
        
        private lazy var separator: UIView = {
            let view = UIView()
            view.backgroundColor = UIColor.white.withAlphaComponent(0.2)
            return view
        }()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            setupUI()
        }
        
        private func setupUI() {
            contentView.addSubview(title)
            contentView.addSubview(separator)
            contentView.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
            
            title.snp.makeConstraints { make in
                make.centerY.equalToSuperview()
                make.left.equalToSuperview().offset(40)
                make.right.equalToSuperview().offset(-20)
            }
            
            separator.snp.makeConstraints { make in
                make.left.equalToSuperview().offset(40)
                make.right.equalToSuperview()
                make.bottom.equalToSuperview()
                make.height.equalTo(0.5)
            }
        }
        
        func bindData(with forum: Forum?) {
            title.text = forum?.name ?? ""
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}
