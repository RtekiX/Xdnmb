//
//  ViewController.swift
//  Xdnmb
//
//  Created by wuzhenghao on 2025/4/30.
//

import UIKit
import SnapKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 设置背景颜色
        view.backgroundColor = .white
        
        // 设置标题
        title = "Xdnmb"
        
        // 添加一个标签
        let label = UILabel()
        label.text = "Hello, Xdnmb!"
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        
        // 设置约束
        label.snp.makeConstraints { make in
            make.left.equalTo(30)
            make.centerY.equalToSuperview()
        }
        
        print("ViewController did load")
    }


}

