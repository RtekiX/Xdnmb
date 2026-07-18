//
// DecodingUtilities.swift
// Author: Maru
//

import Foundation

extension KeyedDecodingContainer {
    func lossyString(forKey key: Key) -> String {
        lossyOptionalString(forKey: key) ?? ""
    }

    func lossyOptionalString(forKey key: Key) -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: key) { return value }
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return String(value) }
        if let value = try? decodeIfPresent(Double.self, forKey: key) { return String(value) }
        if let value = try? decodeIfPresent(Bool.self, forKey: key) { return value ? "true" : "false" }
        return nil
    }

    func lossyInt(forKey key: Key) -> Int {
        lossyOptionalInt(forKey: key) ?? 0
    }

    func lossyOptionalInt(forKey key: Key) -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return value }
        if let value = try? decodeIfPresent(Double.self, forKey: key), value.isFinite {
            return Int(value)
        }
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if let value = try? decodeIfPresent(Bool.self, forKey: key) { return value ? 1 : 0 }
        return nil
    }

    func lossyBool(forKey key: Key) -> Bool {
        lossyOptionalBool(forKey: key) ?? false
    }

    func lossyOptionalBool(forKey key: Key) -> Bool? {
        if let value = try? decodeIfPresent(Bool.self, forKey: key) { return value }
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return value != 0 }
        if let value = try? decodeIfPresent(Double.self, forKey: key) { return value != 0 }
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "1", "true", "yes", "y": return true
            case "0", "false", "no", "n", "": return false
            default: return nil
            }
        }
        return nil
    }

    func lossyArray<Element: Decodable>(_ type: Element.Type, forKey key: Key) -> [Element] {
        guard let wrapper = try? decodeIfPresent(LossyArray<Element>.self, forKey: key) else { return [] }
        return wrapper.elements
    }
}

private struct LossyArray<Element: Decodable>: Decodable {
    let elements: [Element]

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var result: [Element] = []
        result.reserveCapacity(container.count ?? 0)

        while !container.isAtEnd {
            if let element = try container.decode(FailableElement<Element>.self).value {
                result.append(element)
            }
        }
        elements = result
    }
}

private struct FailableElement<Element: Decodable>: Decodable {
    let value: Element?

    init(from decoder: Decoder) throws {
        value = try? Element(from: decoder)
    }
}
