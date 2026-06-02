//
// PaginationArchitecture.swift
// Xdnmb
//
// Created by Pagination Module Architecture
//

import UIKit
import SnapKit

// MARK: - Pagination Model (Context)

struct PaginationContext {
    var currentPage: Int = 1
    var totalPages: Int = 1
    
    mutating func nextPage() -> Bool {
        if currentPage < totalPages {
            currentPage += 1
            return true
        }
        return false
    }
    
    mutating func previousPage() -> Bool {
        if currentPage > 1 {
            currentPage -= 1
            return true
        }
        return false
    }
    
    mutating func jumpToPage(_ page: Int) -> Bool {
        guard page >= 1, page <= totalPages else {
            return false
        }
        currentPage = page
        return true
    }
    
    mutating func setTotalPages(_ pages: Int) {
        totalPages = max(1, pages)
    }
    
    mutating func reset() {
        currentPage = 1
        totalPages = 1
    }
}

// MARK: - Pagination Service

protocol PaginationServiceProtocol: ServiceProtocol where Context == PaginationContext {
    func nextPage() -> Bool
    func previousPage() -> Bool
    func jumpToPage(_ page: Int) -> Bool
    func setTotalPages(_ pages: Int)
    func reset()
}

class PaginationService: PaginationServiceProtocol {
    private(set) var context: PaginationContext
    
    init(context: PaginationContext = PaginationContext()) {
        self.context = context
    }
    
    func nextPage() -> Bool {
        return context.nextPage()
    }
    
    func previousPage() -> Bool {
        return context.previousPage()
    }
    
    func jumpToPage(_ page: Int) -> Bool {
        return context.jumpToPage(page)
    }
    
    func setTotalPages(_ pages: Int) {
        context.setTotalPages(pages)
    }
    
    func reset() {
        context.reset()
    }
}

// MARK: - Pagination View Model

struct PaginationViewModel {
    let currentPage: Int
    let totalPages: Int
    let pageInfoText: String
    
    init(context: PaginationContext) {
        self.currentPage = context.currentPage
        self.totalPages = context.totalPages
        self.pageInfoText = "第 \(context.currentPage) 页 / 共 \(context.totalPages) 页"
    }
}

// MARK: - Pagination View

protocol PaginationViewProtocol: ViewProtocol where ViewModel == PaginationViewModel {
    func clearInputField()
}

class PaginationControlView: UIView, PaginationViewProtocol {
    // UI Components
    private let pageInfoLabel = UILabel()
    private let pageInputTextField = UITextField()
    private let jumpButton = UIButton(type: .system)
    private let prevButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)
    
    private var currentViewModel: PaginationViewModel?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        backgroundColor = .lightGray
        
        setupPageInfoLabel()
        setupPageInputTextField()
        setupJumpButton()
        setupPrevButton()
        setupNextButton()
    }
    
    private func setupPageInfoLabel() {
        pageInfoLabel.font = UIFont.systemFont(ofSize: 14)
        pageInfoLabel.textColor = .darkGray
        pageInfoLabel.textAlignment = .center
        addSubview(pageInfoLabel)
        
        pageInfoLabel.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview().inset(5)
            make.height.equalTo(20)
        }
    }
    
    private func setupPageInputTextField() {
        pageInputTextField.placeholder = "输入页码"
        pageInputTextField.borderStyle = .roundedRect
        pageInputTextField.keyboardType = .numberPad
        pageInputTextField.textAlignment = .center
        pageInputTextField.font = UIFont.systemFont(ofSize: 14)
        addSubview(pageInputTextField)
        
        pageInputTextField.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(10)
            make.top.equalTo(pageInfoLabel.snp.bottom).offset(5)
            make.height.equalTo(30)
            make.width.equalTo(100)
        }
    }
    
    private func setupJumpButton() {
        jumpButton.setTitle("跳转", for: .normal)
        jumpButton.backgroundColor = .systemBlue
        jumpButton.setTitleColor(.white, for: .normal)
        jumpButton.layer.cornerRadius = 5
        jumpButton.clipsToBounds = true
        addSubview(jumpButton)
        
        jumpButton.snp.makeConstraints { make in
            make.left.equalTo(pageInputTextField.snp.right).offset(10)
            make.centerY.equalTo(pageInputTextField)
            make.width.equalTo(60)
            make.height.equalTo(30)
        }
    }
    
    private func setupPrevButton() {
        prevButton.setTitle("< 上一页", for: .normal)
        prevButton.backgroundColor = .systemGray
        prevButton.setTitleColor(.white, for: .normal)
        prevButton.layer.cornerRadius = 5
        prevButton.clipsToBounds = true
        addSubview(prevButton)
        
        prevButton.snp.makeConstraints { make in
            make.left.equalTo(jumpButton.snp.right).offset(10)
            make.centerY.equalTo(pageInputTextField)
            make.width.equalTo(70)
            make.height.equalTo(30)
        }
    }
    
    private func setupNextButton() {
        nextButton.setTitle("下一页 >", for: .normal)
        nextButton.backgroundColor = .systemGray
        nextButton.setTitleColor(.white, for: .normal)
        nextButton.layer.cornerRadius = 5
        nextButton.clipsToBounds = true
        addSubview(nextButton)
        
        nextButton.snp.makeConstraints { make in
            make.left.equalTo(prevButton.snp.right).offset(10)
            make.centerY.equalTo(pageInputTextField)
            make.width.equalTo(70)
            make.height.equalTo(30)
            make.right.lessThanOrEqualToSuperview().offset(-10)
        }
    }
    
    // MARK: - ViewProtocol Implementation
    
    func updateUI(with viewModel: PaginationViewModel) {
        currentViewModel = viewModel
        pageInfoLabel.text = viewModel.pageInfoText
    }
    
    func clearInputField() {
        pageInputTextField.text = ""
    }
    
    // MARK: - Public Interface
    
    func getInputPageNumber() -> Int? {
        guard let text = pageInputTextField.text, !text.isEmpty else { return nil }
        return Int(text)
    }
    
    func getJumpButton() -> UIButton {
        return jumpButton
    }
    
    func getPrevButton() -> UIButton {
        return prevButton
    }
    
    func getNextButton() -> UIButton {
        return nextButton
    }
}

// MARK: - Pagination Controller

protocol PaginationControllerProtocol: ControllerProtocol where View == PaginationControlView, Context == PaginationContext {
    func onJumpButtonTapped()
    func onPrevButtonTapped()
    func onNextButtonTapped()
}

class PaginationController: AbstractController<PaginationControlView, PaginationContext>, PaginationControllerProtocol {
    
    var onPageChanged: ((Int) -> Void)?
    var onError: ((String) -> Void)?
    
    override init(view: PaginationControlView, context: PaginationContext) {
        super.init(view: view, context: context)
        updateViewWithContext()
    }
    
    override func setupBindings() {
        view.getJumpButton().addTarget(self, action: #selector(onJumpButtonTapped), for: .touchUpInside)
        view.getPrevButton().addTarget(self, action: #selector(onPrevButtonTapped), for: .touchUpInside)
        view.getNextButton().addTarget(self, action: #selector(onNextButtonTapped), for: .touchUpInside)
    }
    
    @objc func onJumpButtonTapped() {
        guard let page = view.getInputPageNumber() else {
            onError?("请输入有效的页码")
            return
        }
        
        if context.jumpToPage(page) {
            view.clearInputField()
            updateViewWithContext()
            onPageChanged?(context.currentPage)
        } else {
            onError?("页码范围: 1 - \(context.totalPages)")
        }
    }
    
    @objc func onPrevButtonTapped() {
        if context.previousPage() {
            updateViewWithContext()
            onPageChanged?(context.currentPage)
        } else {
            onError?("已是第一页")
        }
    }
    
    @objc func onNextButtonTapped() {
        if context.nextPage() {
            updateViewWithContext()
            onPageChanged?(context.currentPage)
        } else {
            onError?("已是最后一页")
        }
    }
    
    // MARK: - Public Methods
    
    func updateTotalPages(_ pages: Int) {
        context.setTotalPages(pages)
        updateViewWithContext()
    }
    
    func getCurrentPage() -> Int {
        return context.currentPage
    }
    
    override func reset() {
        context.reset()
        view.clearInputField()
        updateViewWithContext()
    }
    
    // MARK: - Private Methods
    
    private func updateViewWithContext() {
        let viewModel = PaginationViewModel(context: context)
        view.updateUI(with: viewModel)
    }
}
