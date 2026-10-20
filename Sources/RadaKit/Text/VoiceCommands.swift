/// Spoken formatting commands: «новый абзац», «новая строка» and English equivalents.
enum VoiceCommands {
    private struct Command {
        let pattern: Pattern
        let separator: String
    }

    private static let commands: [Command] = [
        Command(pattern: .phrase("новый абзац"), separator: "\n\n"),
        Command(pattern: .phrase("с нового абзаца"), separator: "\n\n"),
        Command(pattern: .phrase("new paragraph"), separator: "\n\n"),
        Command(pattern: .phrase("новая строка"), separator: "\n"),
        Command(pattern: .phrase("с новой строки"), separator: "\n"),
        Command(pattern: .phrase("new line"), separator: "\n"),
    ]

    private static let leadingPunctuation: Set<Character> = [".", ",", ";", ":", "!", "?", "…", " ", "\n"]
    private static let trailingSoftPunctuation: Set<Character> = [",", ";", ":", "-", "—", " "]

    static func apply(to text: String) -> String {
        var result = text
        for command in commands {
            while let range = command.pattern.matches(in: result).first {
                result = replace(range, in: result, separator: command.separator)
            }
        }
        return result
    }

    /// A break ends the sentence before it and starts a new one after it.
    private static func replace(_ range: Range<String.Index>, in text: String, separator: String) -> String {
        var before = String(text[..<range.lowerBound])
        var after = Substring(text[range.upperBound...])

        while let last = before.last, trailingSoftPunctuation.contains(last) { before.removeLast() }
        if let last = before.last, last.isLetter || last.isNumber || last == "»" || last == "\"" || last == ")" {
            before.append(".")
        }
        while let first = after.first, leadingPunctuation.contains(first) { after.removeFirst() }

        let tail = after.prefix(1).uppercased() + after.dropFirst()
        if before.isEmpty { return tail }
        return before + separator + tail
    }
}
