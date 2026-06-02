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
    private var currentPage: Int = 1
    private var totalPages: Int = 1
    
    // UI Components for pagination
    private var pageControlView: UIView?
    private var pageInputTextField: UITextField?
    private var pageInfoLabel: UILabel?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .gray
        
        // Setup page control view first
        setupPageControlView()
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
        collectionView?.backgroundColor = .white
        view.addSubview(collectionView!)
        collectionView?.snp.makeConstraints { make in
            make.top.equalTo(pageControlView!.snp.bottom)
            make.left.right.bottom.equalTo(view.safeAreaLayoutGuide)
        }
        setupCollectionView()
        loadData()
    }

    private func setupPageControlView() {
        pageControlView = UIView()
        pageControlView?.backgroundColor = .lightGray
        view.addSubview(pageControlView!)
        
        pageControlView?.snp.makeConstraints { make in
            make.top.left.right.equalTo(view.safeAreaLayoutGuide)
            make.height.equalTo(60)
        }
        
        // Page info label
        pageInfoLabel = UILabel()
        pageInfoLabel?.text = "第 1 页 / 共 1 页"
        pageInfoLabel?.font = UIFont.systemFont(ofSize: 14)
        pageInfoLabel?.textColor = .darkGray
        pageInfoLabel?.textAlignment = .center
        pageControlView?.addSubview(pageInfoLabel!)
        pageInfoLabel?.snp.makeConstraints { make in
            make.top.equalTo(pageControlView!).offset(5)
            make.left.right.equalTo(pageControlView!)
            make.height.equalTo(20)
        }
        
        // Page input field
        pageInputTextField = UITextField()
        pageInputTextField?.placeholder = "输入页码"
        pageInputTextField?.borderStyle = .roundedRect
        pageInputTextField?.keyboardType = .numberPad
        pageInputTextField?.textAlignment = .center
        pageInputTextField?.font = UIFont.systemFont(ofSize: 14)
        pageControlView?.addSubview(pageInputTextField!)
        pageInputTextField?.snp.makeConstraints { make in
            make.left.equalTo(pageControlView!).offset(10)
            make.top.equalTo(pageInfoLabel!.snp.bottom).offset(5)
            make.height.equalTo(30)
            make.width.equalTo(100)
        }
        
        // Jump button
        let jumpButton = UIButton(type: .system)
        jumpButton.setTitle("跳转", for: .normal)
        jumpButton.backgroundColor = .systemBlue
        jumpButton.setTitleColor(.white, for: .normal)
        jumpButton.layer.cornerRadius = 5
        jumpButton.addTarget(self, action: #selector(jumpToPage), for: .touchUpInside)
        pageControlView?.addSubview(jumpButton)
        jumpButton.snp.makeConstraints { make in
            make.left.equalTo(pageInputTextField!.snp.right).offset(10)
            make.centerY.equalTo(pageInputTextField!)
            make.width.equalTo(60)
            make.height.equalTo(30)
        }
        
        // Previous page button
        let prevButton = UIButton(type: .system)
        prevButton.setTitle("< 上一页", for: .normal)
        prevButton.backgroundColor = .systemGray
        prevButton.setTitleColor(.white, for: .normal)
        prevButton.layer.cornerRadius = 5
        prevButton.addTarget(self, action: #selector(goToPreviousPage), for: .touchUpInside)
        pageControlView?.addSubview(prevButton)
        prevButton.snp.makeConstraints { make in
            make.left.equalTo(jumpButton.snp.right).offset(10)
            make.centerY.equalTo(pageInputTextField!)
            make.width.equalTo(70)
            make.height.equalTo(30)
        }
        
        // Next page button
        let nextButton = UIButton(type: .system)
        nextButton.setTitle("下一页 >", for: .normal)
        nextButton.backgroundColor = .systemGray
        nextButton.setTitleColor(.white, for: .normal)
        nextButton.layer.cornerRadius = 5
        nextButton.addTarget(self, action: #selector(goToNextPage), for: .touchUpInside)
        pageControlView?.addSubview(nextButton)
        nextButton.snp.makeConstraints { make in
            make.left.equalTo(prevButton.snp.right).offset(10)
            make.centerY.equalTo(pageInputTextField!)
            make.width.equalTo(70)
            make.height.equalTo(30)
        }
    }

    private func setupCollectionView() {
        collectionView?.register(XdMainHomeCell.self, forCellWithReuseIdentifier: "XdMainHomeCell")
        collectionView?.dataSource = self
        collectionView?.delegate = self
    }

    private func loadData() {
        loadDataForPage(currentPage)
    }
    
    private func loadDataForPage(_ page: Int) {
        APIManager.shared.getTimelineThreadList(page: page) { [weak self] result in
            switch result {
            case .success(let threadItems):
                self?.threadItems = threadItems
                self?.collectionView?.reloadData()
                // Update page info (需要从API响应获取总页数)
                self?.updatePageInfo()
            case .failure(let error):
                print("Error loading data: \(error)")
                DispatchQueue.main.async {
                    let alert = UIAlertController(title: "错误", message: "加载数据失败: \(error)", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "确定", style: .default))
                    self?.present(alert, animated: true)
                }
            }
        }
    }
    
    private func updatePageInfo() {
        pageInfoLabel?.text = "第 \(currentPage) 页 / 共 \(totalPages) 页"
        pageInputTextField?.text = ""
    }
    
    @objc private func jumpToPage() {
        guard let pageText = pageInputTextField?.text, !pageText.isEmpty,
              let page = Int(pageText) else {
            showAlert(message: "请输入有效的页码")
            return
        }
        
        if page < 1 || page > totalPages {
            showAlert(message: "页码范围: 1 - \(totalPages)")
            return
        }
        
        currentPage = page
        loadDataForPage(currentPage)
    }
    
    @objc private func goToPreviousPage() {
        if currentPage > 1 {
            currentPage -= 1
            loadDataForPage(currentPage)
        } else {
            showAlert(message: "已是第一页")
        }
    }
    
    @objc private func goToNextPage() {
        if currentPage < totalPages {
            currentPage += 1
            loadDataForPage(currentPage)
        } else {
            showAlert(message: "已是最后一页")
        }
    }
    
    private func showAlert(message: String) {
        let alert = UIAlertController(title: "提示", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
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
