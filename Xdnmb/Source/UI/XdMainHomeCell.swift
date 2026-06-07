// 
// XdMainHomeCell.swift
// Xdnmb
// 
// Created by Yuno's on 2025/05/07.
// 

import UIKit
import SnapKit
import Foundation

class XdMainHomeCell: UICollectionViewCell {
    private lazy var authorNameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .gray
        return label
    }()
    
    private lazy var timeLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .gray
        label.numberOfLines = 0
        return label
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = .black
        return label
    }()

    private lazy var thumbnailImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        contentView.addSubview(authorNameLabel)
        contentView.addSubview(timeLabel)
        contentView.addSubview(titleLabel)
        contentView.addSubview(thumbnailImageView)

        authorNameLabel.snp.makeConstraints { make in
            make.left.equalTo(5)
            make.top.equalTo(8)
        }

        timeLabel.snp.makeConstraints { make in
            make.left.equalTo(authorNameLabel.snp.right).offset(5)
            make.top.equalTo(authorNameLabel)
        }

        titleLabel.snp.makeConstraints { make in
            make.left.equalTo(5)
            make.right.equalTo(-5)
            make.top.equalTo(authorNameLabel.snp.bottom).offset(5)
        }

        thumbnailImageView.snp.makeConstraints { make in
            make.left.equalTo(5)
            make.right.equalTo(-5)
            make.top.equalTo(titleLabel.snp.bottom).offset(5)
            make.height.lessThanOrEqualTo(100)
        }
    }

    func bindData(with data: ThreadItem) {
        authorNameLabel.text = data.authorName
        timeLabel.text = data.time
        titleLabel.text = data.title
        thumbnailImageView.image = data.thumbnailImage
    }
}