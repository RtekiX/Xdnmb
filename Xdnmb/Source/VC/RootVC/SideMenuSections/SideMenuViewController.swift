//
//  SideMenuViewController.swift
//  Xdnmb
//
//  Created by Yuno's on 2025/5/6.
//

import UIKit
import Foundation
import SnapKit

protocol SideMenuNavigationDelegate: AnyObject {
    func sideMenuDidSelectForum(_ forum: Forum)
}

class SideMenuViewController: UIViewController {
    weak var navigationDelegate: SideMenuNavigationDelegate?
    private enum SectionType: Int, CaseIterable {
        case bannder = 0
        case setting
        case module
    }
    
    private lazy var sectionManagers: [SectionManagable] = [
        BannerSection(with: listCollectionView),
        SettingSection(with: listCollectionView),
        ModuleSection(with: listCollectionView)
    ]

    private lazy var listCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(SideMenuCell.self, forCellWithReuseIdentifier: "cell")
        collectionView.backgroundColor = .clear
        collectionView.contentInsetAdjustmentBehavior = .always
        return collectionView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupCollectionView()
        setupSections()
    }
    
    private func setupCollectionView() {
        view.addSubview(listCollectionView)
        listCollectionView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.leading.equalTo(view.safeAreaLayoutGuide.snp.leading)
            make.trailing.equalTo(view.safeAreaLayoutGuide.snp.trailing)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
        }
        listCollectionView.showsVerticalScrollIndicator = false
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        listCollectionView.collectionViewLayout.invalidateLayout()
    }

    private func setupSections() {
        sectionManagers.forEach { listCollectionView.register($0.cellClass, forCellWithReuseIdentifier: $0.cellIdentifier) }
    }
    
    private func getSectionManager(of type: SectionType) -> SectionManagable? {
        let index = type.rawValue
        guard index > 0, index <= self.sectionManagers.count else {
            return nil
        }
        return self.sectionManagers[index]
    }
}

extension SideMenuViewController {
    func loadData() {
        guard let moduleSectionManager = getSectionManager(of: .module) as? ModuleSection else {
            return
        }
        moduleSectionManager.loadData()
    }
}

extension SideMenuViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard sectionManagers.count > section, section >= 0 else { return 0 }
        return sectionManagers[section].numberOfItems()
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard sectionManagers.count > indexPath.section, indexPath.section >= 0 else { return UICollectionViewCell() }
        return sectionManagers[indexPath.section].cellForItem(at: indexPath.row)
    }

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        sectionManagers.count
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard sectionManagers.count > indexPath.section, indexPath.section >= 0 else { return }
        sectionManagers[indexPath.section].didSelectItem(at: indexPath.row)
    }
}

extension SideMenuViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        sectionManagers[indexPath.section].sizeForItem(at: indexPath.row)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        .zero
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        0
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        0
    }
}

extension SideMenuViewController {
    class SideMenuCell: UICollectionViewCell {
        lazy var titleLabel: UILabel = {
            let label = UILabel()
            label.textAlignment = .center
            return label
        }()

        override init(frame: CGRect) {
            super.init(frame: frame)
            contentView.addSubview(titleLabel)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}
