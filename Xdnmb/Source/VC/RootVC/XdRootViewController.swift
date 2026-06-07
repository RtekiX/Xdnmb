//
//  XdRootViewController.swift
//  Xdnmb
//
//  Created by Yuno's on 2025/5/6.
//

import UIKit
import AFNetworking

class RootContentViewController: UIViewController, SideMenuNavigationDelegate {
    private lazy var sideMenuVC: SideMenuViewController = {
        let sideMenuVC = SideMenuViewController()
        sideMenuVC.navigationDelegate = self
        sideMenuVC.modalPresentationStyle = .overFullScreen
        return sideMenuVC
    }()
    
    private lazy var mainHomeVC: XdMainHomeViewController = {
        let mainHomeVC = XdMainHomeViewController()
        return mainHomeVC
    }()
    
    private var currentContentVC: UIViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = "xdnmb"
        setupNavigationBar()
        setupLeftBarButtonItem()
        setupRightBarButtonItem()
        setupSideMenu()
        setupMainHomeVC()
    }

    private func setupNavigationBar() {
        navigationController?.navigationBar.backgroundColor = .green
        navigationController?.navigationBar.tintColor = .black
        navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.black]
    }

    private func setupLeftBarButtonItem() {
        let leftBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "line.3.horizontal"), style: .plain, target: self, action: #selector(leftBarButtonItemTapped))
        navigationItem.leftBarButtonItem = leftBarButtonItem
    }

    @objc private func leftBarButtonItemTapped() {
        openPopUpMenu()
        print("leftBarButtonItemTapped")
    }
    
    private func setupRightBarButtonItem() {
        let rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "pencil.line"), style: .plain, target: self, action: #selector(rightBarButtonItemTapped))
        navigationItem.rightBarButtonItem = rightBarButtonItem
    }

    @objc private func rightBarButtonItemTapped() {
        print("rightBarButtonItemTapped")
    }
    
    private func setupSideMenu() {
        self.sideMenuVC.loadData()
    }

    private func setupMainHomeVC() {
        currentContentVC = mainHomeVC
        self.xd_addChild(mainHomeVC)
    }
    
    private func openPopUpMenu() {
        // 获取导航控制器的视图
        guard let navController = navigationController else { return }
        
        // 设置菜单视图的frame
        sideMenuVC.view.frame = CGRect(x: -navController.view.bounds.width * 0.8, y: 0, width: navController.view.bounds.width * 0.8, height: navController.view.bounds.height)
        
        // 添加半透明背景
        let dimView = UIView(frame: navController.view.bounds)
        dimView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        dimView.alpha = 0
        navController.view.addSubview(dimView)
        
        // 添加点击手势
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDimViewTap))
        dimView.addGestureRecognizer(tapGesture)
        
        // 添加菜单视图到导航控制器的视图层级
        navController.view.addSubview(sideMenuVC.view)
        navController.addChild(sideMenuVC)
        sideMenuVC.didMove(toParent: navController)
        
        // 动画显示
        UIView.animate(withDuration: 0.3) {
            self.sideMenuVC.view.transform = CGAffineTransform(translationX: navController.view.bounds.width * 0.8, y: 0)
            dimView.alpha = 1
        }
    }
    
    @objc private func handleDimViewTap() {
        closeSideMenu()
    }
    
    private func closeSideMenu() {
        guard let navController = navigationController else { return }
        
        UIView.animate(withDuration: 0.3, animations: {
            self.sideMenuVC.view.transform = .identity
            navController.view.subviews.first(where: { $0.backgroundColor == UIColor.black.withAlphaComponent(0.5) })?.alpha = 0
        }) { [weak self] _ in
            self?.sideMenuVC.willMove(toParent: nil)
            self?.sideMenuVC.view.removeFromSuperview()
            self?.sideMenuVC.removeFromParent()
            navController.view.subviews.first(where: { $0.backgroundColor == UIColor.black.withAlphaComponent(0.5) })?.removeFromSuperview()
        }
    }
    
    // MARK: - SideMenuNavigationDelegate
    func sideMenuDidSelectForum(_ forum: Forum) {
        closeSideMenu()
        
        // 替换当前内容视图为论坛视图
        let forumVC = ForumViewController(forumId: Int(forum.id) ?? 0)
        forumVC.title = forum.name
        
        if let currentVC = currentContentVC {
            xd_removeChild(currentVC)
        }
        
        currentContentVC = forumVC
        xd_addChild(forumVC)
    }
}

class XdRootViewController: UINavigationController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let rootVC = RootContentViewController()
        setViewControllers([rootVC], animated: false)
    }
}

extension UIViewController {
    func xd_mostTopViewController() -> UIViewController {
        if let presented = presentedViewController {
            return presented.xd_mostTopViewController()
        }
        
        if let navigationController = self as? UINavigationController {
            return navigationController.visibleViewController?.xd_mostTopViewController() ?? navigationController
        }
        
        if let tabBarController = self as? UITabBarController {
            return tabBarController.selectedViewController?.xd_mostTopViewController() ?? tabBarController
        }
        
        return self
    }
    
    func xd_addChild(_ child: UIViewController) {
        addChild(child)
        view.addSubview(child.view)
        child.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        child.didMove(toParent: self)
    }

    func xd_removeChild(_ child: UIViewController) {
        child.willMove(toParent: nil)
        child.view.removeFromSuperview()
        child.removeFromParent()
    }
}
