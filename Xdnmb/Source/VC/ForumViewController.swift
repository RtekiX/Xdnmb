//
//  ForumViewController.swift
//  Xdnmb
//
//  Created by Maru on 2026/6/13.
//

import UIKit

final class ForumViewController: UIViewController {
    private let forumId: Int

    init(forumId: Int) {
        self.forumId = forumId
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
    }
}
