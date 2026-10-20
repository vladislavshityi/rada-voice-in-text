/// Turns raw recognizer output into text ready to insert.
///
/// Every step is conservative: it may remove recognizer artefacts, apply the
/// user's dictionary and tidy whitespace, but never rewrites the speech itself.
public struct TextProcessor: Sendable {
    public struct Options: Sendable {
        public var voiceCommands: Bool

        public init(voiceCommands: Bool) {
            self.voiceCommands = voiceCommands
        }
    }

    private let corrector: DictionaryCorrector
    private let options: Options

    public init(dictionary: [DictionaryEntry], options: Options) {
        corrector = DictionaryCorrector(entries: dictionary)
        self.options = options
    }

    public func process(_ raw: String) -> String {
        var text = HallucinationFilter.clean(raw)
        if options.voiceCommands {
            text = VoiceCommands.apply(to: text)
        }
        text = corrector.apply(to: text)
        return TextNormalizer.normalize(text)
    }
}
