// 
// XdMainHomeViewController.swift
// Xdnmb
// 
// Created by Yuno's on 2025/05/07.
// 

import UIKit
import SnapKit
import Foundation

class XdMainHomeViewController: UIViewController {
    private var collectionView: UICollectionView?
    private var threadItems: [ThreadItem] = []
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .gray
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
        collectionView?.backgroundColor = .white
        view.addSubview(collectionView!)
        collectionView?.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }
        setupCollectionView()
        loadData()
    }

    private func setupCollectionView() {
        collectionView?.register(XdMainHomeCell.self, forCellWithReuseIdentifier: "XdMainHomeCell")
    }

    private func loadData() {
        APIManager.shared.getTimelineThreadList { [weak self] result in
            switch result {
            case .success(let threadItems):
                self?.threadItems = threadItems
                self?.collectionView?.reloadData()
            case .failure(let error):
                print("Error loading data: \(error)")
            }
        }
    }
}

extension XdMainHomeViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return threadItems.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard indexPath.item < threadItems.count else {
            return UICollectionViewCell()
        }

        if let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "XdMainHomeCell", for: indexPath) as? XdMainHomeCell {
            cell.bindData(with: threadItems[indexPath.item])
            return cell
        }
        return UICollectionViewCell()
    } 

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, estimatedSizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.frame.width, height: 100)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 10
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 10
    }
    
}
