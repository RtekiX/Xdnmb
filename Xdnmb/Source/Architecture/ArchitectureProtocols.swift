//
// ArchitectureProtocols.swift
// Xdnmb
//
// Created by Architecture Foundation
//

import UIKit

// MARK: - Service Protocol

/// Service 协议：纯逻辑组件，不包含 UI
/// 定义业务逻辑的抽象接口
protocol ServiceProtocol {
    associatedtype Context
    var context: Context { get }
}

// MARK: - View Protocol

/// View 协议：UI 视图接口
protocol ViewProtocol: UIView {
    associatedtype ViewModel
    func updateUI(with viewModel: ViewModel)
}

// MARK: - Controller Protocol

/// Controller 协议：包含 UI 和逻辑的独立组件
/// 使用泛型关联 View 类型和上下文类型
protocol ControllerProtocol: AnyObject {
    associatedtype View: ViewProtocol
    associatedtype Context
    
    var view: View { get }
    var context: Context { get }
    
    func setupBindings()
    func reset()
}

// MARK: - Abstract Controller Base Class

/// 抽象的 Controller<View> 基类
/// 实现通用的 Controller 逻辑框架
open class AbstractController<V: ViewProtocol, C>: ControllerProtocol {
    public let view: V
    public var context: C
    
    public init(view: V, context: C) {
        self.view = view
        self.context = context
        setupBindings()
    }
    
    /// 子类需要实现此方法来设置绑定
    open func setupBindings() {
        // 子类应重写此方法
    }
    
    /// 重置控制器状态
    open func reset() {
        // 子类可选重写此方法
    }
}
