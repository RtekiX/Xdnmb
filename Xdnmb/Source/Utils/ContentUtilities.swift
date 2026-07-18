//
// ContentUtilities.swift
// Author: Maru
//

import Foundation

extension String {
    var nilIfBlank: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    var htmlPlainText: String {
        var value = self
        let lineBreakPatterns = [
            "(?i)<br\\s*/?>",
            "(?i)</p\\s*>",
            "(?i)</div\\s*>",
            "(?i)</li\\s*>"
        ]
        for pattern in lineBreakPatterns {
            value = value.replacingOccurrences(of: pattern, with: "\n", options: .regularExpression)
        }
        value = value.replacingOccurrences(of: "<[^>]*>", with: "", options: .regularExpression)
        value = value.decodingHTMLEntities
        value = value.replacingOccurrences(of: "\\r\\n?", with: "\n", options: .regularExpression)
        value = value.replacingOccurrences(of: "[ \\t]+\\n", with: "\n", options: .regularExpression)
        value = value.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var decodingHTMLEntities: String {
        var value = self
        let named: [String: String] = [
            "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"",
            "&#39;": "'", "&apos;": "'", "&nbsp;": " ", "&bull;": "•",
            "&ldquo;": "“", "&rdquo;": "”", "&lsquo;": "‘", "&rsquo;": "’"
        ]
        for (entity, replacement) in named {
            value = value.replacingOccurrences(of: entity, with: replacement, options: .caseInsensitive)
        }

        let pattern = "&#(x?[0-9A-Fa-f]+);"
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return value }
        let matches = expression.matches(in: value, range: NSRange(value.startIndex..., in: value)).reversed()
        for match in matches {
            guard let range = Range(match.range(at: 0), in: value),
                  let numberRange = Range(match.range(at: 1), in: value) else { continue }
            let token = String(value[numberRange])
            let radix = token.lowercased().hasPrefix("x") ? 16 : 10
            let digits = radix == 16 ? String(token.dropFirst()) : token
            guard let codePoint = UInt32(digits, radix: radix),
                  let scalar = UnicodeScalar(codePoint) else { continue }
            value.replaceSubrange(range, with: String(scalar))
        }
        return value
    }
}

extension Array where Element: Identifiable {
    func appendingUnique(_ newElements: [Element]) -> [Element] where Element.ID: Hashable {
        var seen = Set(map(\.id))
        return self + newElements.filter { seen.insert($0.id).inserted }
    }
}
