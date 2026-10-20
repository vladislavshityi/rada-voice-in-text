import Foundation

/// Minimal sentence segmentation shared by text processing steps.
enum Sentences {
    /// Splits text into sentences, keeping terminal punctuation and following whitespace.
    static func split(_ text: String) -> [String] {
        var result: [String] = []
        var current = ""
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            current.append(character)
            index = text.index(after: index)
            guard isTerminal(character) || character == "\n" else { continue }
            // Absorb the whole terminal run ("?!", "...") and trailing spaces.
            while index < text.endIndex, isTerminal(text[index]) || text[index].isWhitespace {
                current.append(text[index])
                index = text.index(after: index)
            }
            result.append(current)
            current = ""
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    /// Lowercased letters and digits separated by single spaces; used for comparisons.
    static func normalized(_ sentence: String) -> String {
        sentence.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    static func isTerminal(_ character: Character) -> Bool {
        character == "." || character == "!" || character == "?" || character == "…"
    }
}
