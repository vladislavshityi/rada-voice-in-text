/// Applies the user's dictionary to recognized text.
///
/// 1. Known misrecognitions (variants) are replaced with the canonical term.
/// 2. Distinctive spellings (acronyms, Latin, mixed case) are restored when the
///    recognizer produced the same word in different letter case — e.g. «вшэ» → «ВШЭ».
///    Plain capitalized words are left alone so a term like «Мир» never alters «мир».
struct DictionaryCorrector: Sendable {
    private struct Rule: Sendable {
        let pattern: Pattern
        let term: String
        let length: Int
    }

    private let rules: [Rule]

    init(entries: [DictionaryEntry]) {
        var rules: [Rule] = []
        for entry in entries where !entry.trimmedTerm.isEmpty {
            let term = entry.trimmedTerm
            rules += entry.cleanVariants.map { Rule(pattern: .phrase($0), term: term, length: $0.count) }
            if Self.hasDistinctiveCasing(term) {
                rules.append(Rule(pattern: .phrase(term), term: term, length: term.count))
            }
        }
        // Longer phrases first, so «Высшая школа экономики» wins over «школа».
        self.rules = rules.sorted { $0.length > $1.length }
    }

    func apply(to text: String) -> String {
        rules.reduce(text) { text, rule in
            rule.pattern.replacing(in: text) { match in Self.adapt(rule.term, toCaseOf: match) }
        }
    }

    /// Keeps a sentence-initial capital when the term itself starts lowercase.
    private static func adapt(_ term: String, toCaseOf match: Substring) -> String {
        guard let first = match.first, first.isUppercase, let termFirst = term.first, termFirst.isLowercase,
              !hasDistinctiveCasing(term)
        else { return term }
        return term.prefix(1).uppercased() + term.dropFirst()
    }

    static func hasDistinctiveCasing(_ term: String) -> Bool {
        let letters = term.filter(\.isLetter)
        guard letters.count > 1 else { return false }
        let hasLatin = letters.contains { $0.isASCII }
        let innerUppercase = letters.dropFirst().contains(where: \.isUppercase)
        return hasLatin || innerUppercase || term.contains(where: \.isNumber)
    }
}
