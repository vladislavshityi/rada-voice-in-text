/// Whitespace, spacing around punctuation and capitalization — nothing else.
enum TextNormalizer {
    private static let horizontalSpace = Pattern("[ \\t\\u00A0]+")
    private static let spaceBeforePunctuation = Pattern(" +([,.!?;:…%»)])")
    private static let spaceAfterOpening = Pattern("([«(]) +")
    private static let missingSpaceAfterComma = Pattern("([,;])(\\p{L})")
    private static let missingSpaceAfterSentence = Pattern("(\\p{Ll}[.!?…])(\\p{Lu}\\p{Ll})")
    private static let excessBlankLines = Pattern("\\n{3,}")

    static func normalize(_ text: String) -> String {
        var result = text.replacingOccurrences(of: "\r\n", with: "\n")
        result = horizontalSpace.replacing(in: result, with: " ")
        result = result
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")
        result = spaceBeforePunctuation.replacing(in: result, with: "$1")
        result = spaceAfterOpening.replacing(in: result, with: "$1")
        result = missingSpaceAfterComma.replacing(in: result, with: "$1 $2")
        result = missingSpaceAfterSentence.replacing(in: result, with: "$1 $2")
        result = excessBlankLines.replacing(in: result, with: "\n\n")
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        result = capitalizeLineStarts(result)
        return terminate(result)
    }

    private static func capitalizeLineStarts(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in
                guard let first = line.first, first.isLowercase else { return String(line) }
                return first.uppercased() + line.dropFirst()
            }
            .joined(separator: "\n")
    }

    /// Dictation is written prose: a final sentence without punctuation gets a period.
    private static func terminate(_ text: String) -> String {
        guard let last = text.last, last.isLetter || last.isNumber else { return text }
        return text + "."
    }
}
