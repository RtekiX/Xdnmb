//
//  Array+Extensions.swift
//  Xdnmb
//
//  Created by Yuno's on 2025/5/7.
//

import Foundation

extension Array {
    subscript<T>(safe index: Int) -> T? {
        guard index >= 0 && index < count else { return nil }
        return self[index] as? T
    }
}