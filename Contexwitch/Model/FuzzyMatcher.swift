//
//  FuzzyMatcher.swift
//  Contexwitch
//

import Foundation

nonisolated enum FuzzyMatcher {
    /// Scores `query` against weighted fields. Every whitespace-separated query
    /// token must match at least one field. Returns nil when there's no match.
    static func score(_ query: String, fields: [(text: String, weight: Int)]) -> Int? {
        var total = 0
        for token in query.split(whereSeparator: \.isWhitespace) {
            let best = fields.compactMap { field in
                score(token: String(token), in: field.text).map { $0 * field.weight }
            }.max()
            guard let best else { return nil }
            total += best
        }
        return total
    }

    private static func score(token: String, in text: String) -> Int? {
        guard !token.isEmpty else { return 0 }
        let haystack = Array(text.lowercased())
        let needle = Array(token.lowercased())

        if let range = text.range(of: token, options: [.caseInsensitive, .diacriticInsensitive]) {
            let start = text.distance(from: text.startIndex, to: range.lowerBound)
            let atWordStart = start == 0 || !(haystack[safe: start - 1]?.isLetter ?? false)
            return 1000 + (start == 0 ? 300 : 0) + (atWordStart ? 150 : 0) - min(start, 100) - haystack.count / 8
        }

        var score = 0
        var cursor = 0
        var previous = -2
        for character in needle {
            guard let index = haystack[cursor...].firstIndex(of: character) else { return nil }
            score += 10
            if index == previous + 1 { score += 15 }
            if index == 0 || !(haystack[index - 1].isLetter || haystack[index - 1].isNumber) { score += 20 }
            score -= min(index - cursor, 10)
            previous = index
            cursor = index + 1
        }
        return score
    }
}

private extension Array {
    nonisolated subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
