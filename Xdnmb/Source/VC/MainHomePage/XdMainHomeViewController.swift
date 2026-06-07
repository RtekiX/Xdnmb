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
    
    // 分页控制器
    private let paginationController = PaginationController(view: PaginationControlView(), context: PaginationContext())
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .gray
        
        // Setup pagination view
        setupPaginationView()
        
        // Setup collection view
        setupCollectionView()
        
        // Load initial data
        loadData()
    }

    private func setupPaginationView() {
        view.addSubview(paginationController.view)
        paginationController.view.snp.makeConstraints { make in
            make.top.left.right.equalTo(view.safeAreaLayoutGuide)
            make.height.equalTo(60)
        }
        
        // Setup callbacks
        paginationController.onPageChanged = { [weak self] page in
            self?.loadDataForPage(page)
        }
        
        paginationController.onError = { [weak self] message in
            self?.showAlert(title: "提示", message: message)
        }
    }

    private func setupCollectionView() {
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
        collectionView?.backgroundColor = .white
        view.addSubview(collectionView!)
        
        collectionView?.snp.makeConstraints { make in
            make.top.equalTo(paginationController.view.snp.bottom)
            make.left.right.bottom.equalTo(view.safeAreaLayoutGuide)
        }
        
        collectionView?.register(XdMainHomeCell.self, forCellWithReuseIdentifier: "XdMainHomeCell")
        collectionView?.dataSource = self
        collectionView?.delegate = self
    }

    private func loadData() {
        loadDataForPage(paginationController.getCurrentPage())
    }
    
    private func loadDataForPage(_ page: Int) {
        APIManager.shared.getTimelineThreadList(page: page) { [weak self] result in
            switch result {
            case .success(let response):
                self?.threadItems = response.threadItems ?? []
                
                // Update pagination with total pages from API
                if let totalPages = response.totalPages {
                    self?.paginationController.updateTotalPages(totalPages)
                }
                
                self?.collectionView?.reloadData()
                
            case .failure(let error):
                print("Error loading data: \(error)")
                DispatchQueue.main.async {
                    self?.showAlert(title: "错误", message: "加载数据失败: \(error)")
                }
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UICollectionViewDataSource & Delegate

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
