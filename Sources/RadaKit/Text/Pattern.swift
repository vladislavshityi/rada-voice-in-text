import Foundation

/// Thin wrapper over `NSRegularExpression` (Swift `Regex` lacks look-behind).
struct Pattern: @unchecked Sendable {
    private let regex: NSRegularExpression

    init(_ pattern: String, caseInsensitive: Bool = false) {
        var options: NSRegularExpression.Options = []
        if caseInsensitive { options.insert(.caseInsensitive) }
        // Patterns are built from escaped literals or constants, so this cannot fail.
        regex = try! NSRegularExpression(pattern: pattern, options: options)
    }

    /// Matches `phrase` as whole words; inner spaces match any whitespace.
    static func phrase(_ phrase: String) -> Pattern {
        let body = phrase
            .split(whereSeparator: \.isWhitespace)
            .map { NSRegularExpression.escapedPattern(for: String($0)) }
            .joined(separator: "\\s+")
        return Pattern("(?<![\\p{L}\\p{N}])\(body)(?![\\p{L}\\p{N}])", caseInsensitive: true)
    }

    func matches(in text: String) -> [Range<String.Index>] {
        regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            .compactMap { Range($0.range, in: text) }
    }

    func replacing(in text: String, with template: String) -> String {
        regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: template)
    }

    /// Replaces every match with the string produced by `transform`.
    func replacing(in text: String, transform: (Substring) -> String) -> String {
        var result = text
        for range in matches(in: text).reversed() {
            result.replaceSubrange(range, with: transform(text[range]))
        }
        return result
    }
}
