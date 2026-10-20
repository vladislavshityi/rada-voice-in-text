/// Removes text that speech models are known to invent on silence or noise.
///
/// Whisper was trained on subtitles, so on quiet input it may emit subtitle
/// credits or sign-offs. Only exact, well-known artefacts are removed.
enum HallucinationFilter {
    /// Removed wherever they appear: they are never part of real dictation.
    private static let creditMarkers = ["dimatorzok", "субтитры сделал", "субтитры создавал",
                                        "субтитры подготовил", "редактор субтитров", "корректор а егорова",
                                        "subtitles by the amara org community"]

    /// Removed only when they are the entire result (typical for silent recordings).
    private static let standalonePhrases: Set<String> = [
        "продолжение следует", "спасибо за просмотр", "спасибо за внимание",
        "thank you for watching", "thanks for watching", "thank you",
    ]

    /// A sentence repeated this many times in a row is a decoder loop.
    private static let loopThreshold = 3

    static func clean(_ text: String) -> String {
        let sentences = Sentences.split(text).filter { sentence in
            let normalized = Sentences.normalized(sentence)
            return !normalized.isEmpty && !creditMarkers.contains { normalized.contains($0) }
        }
        let collapsed = collapseLoops(sentences)
        if collapsed.count == 1, standalonePhrases.contains(Sentences.normalized(collapsed[0])) {
            return ""
        }
        return collapsed.joined()
    }

    private static func collapseLoops(_ sentences: [String]) -> [String] {
        var result: [String] = []
        var index = 0
        while index < sentences.count {
            let key = Sentences.normalized(sentences[index])
            var runEnd = index + 1
            while runEnd < sentences.count, Sentences.normalized(sentences[runEnd]) == key { runEnd += 1 }
            let runLength = runEnd - index
            result.append(contentsOf: runLength >= loopThreshold ? [sentences[index]] : Array(sentences[index..<runEnd]))
            index = runEnd
        }
        return result
    }
}
