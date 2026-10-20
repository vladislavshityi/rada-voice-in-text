import Testing
@testable import RadaKit

struct TextProcessorTests {
    private func process(_ text: String, dictionary: [DictionaryEntry] = [], voiceCommands: Bool = true) -> String {
        TextProcessor(dictionary: dictionary, options: .init(voiceCommands: voiceCommands)).process(text)
    }

    @Test func keepsWellFormedTextUntouched() {
        let text = "Вчера министр финансов Антон Силуанов заявил, что бюджет не будет пересмотрен. Однако эксперты ВШЭ не согласны."
        #expect(process(text) == text)
    }

    @Test func preservesNumbersNegationsAndQuotes() {
        let text = "Он сказал: «Мы не будем повышать налоги в 2027 году». Дефицит — 2,5% ВВП."
        #expect(process(text) == text)
    }

    @Test func tidiesWhitespaceAndCapitalizes() {
        #expect(process("  привет ,  как дела ?") == "Привет, как дела?")
    }

    @Test func terminatesUnpunctuatedText() {
        #expect(process("привет как дела") == "Привет как дела.")
    }

    @Test func doesNotSplitAbbreviations() {
        #expect(process("Штаб-квартира в U.S.A. закрыта.") == "Штаб-квартира в U.S.A. закрыта.")
    }

    @Test func voiceCommandStartsParagraph() {
        #expect(process("Первый абзац, новый абзац, второй абзац.") == "Первый абзац.\n\nВторой абзац.")
        #expect(process("Строка один. Новая строка. Строка два.") == "Строка один.\nСтрока два.")
    }

    @Test func voiceCommandsCanBeDisabled() {
        #expect(process("Скажи «новый абзац».", voiceCommands: false) == "Скажи «новый абзац».")
    }

    @Test func voiceCommandIgnoresPartialWords() {
        #expect(process("Это сверхновый абзацный отступ.") == "Это сверхновый абзацный отступ.")
    }

    @Test func dictionaryReplacesVariants() {
        let entry = DictionaryEntry(term: "Силуанов", variants: "сила ванов, Зельманов", kind: .person)
        #expect(process("Министр Антон сила ванов заявил.", dictionary: [entry]) == "Министр Антон Силуанов заявил.")
        #expect(process("Антон Зельманов заявил.", dictionary: [entry]) == "Антон Силуанов заявил.")
    }

    @Test func dictionaryRestoresDistinctiveCasing() {
        let entries = [DictionaryEntry(term: "ВШЭ", kind: .organization), DictionaryEntry(term: "iPhone")]
        #expect(process("Эксперты вшэ купили айфон и iphone.", dictionary: entries) == "Эксперты ВШЭ купили айфон и iPhone.")
    }

    @Test func dictionaryNeverChangesPlainWords() {
        let entry = DictionaryEntry(term: "Мир", kind: .organization)
        #expect(process("Мы хотим мир.", dictionary: [entry]) == "Мы хотим мир.")
    }

    @Test func dictionaryKeepsSentenceCapital() {
        let entry = DictionaryEntry(term: "блокчейн", variants: "блок чейн")
        #expect(process("Блок чейн растёт.", dictionary: [entry]) == "Блокчейн растёт.")
    }

    @Test func removesSubtitleHallucinations() {
        #expect(process("Продолжение следует...") == "")
        #expect(process("Текст статьи. Субтитры сделал DimaTorzok.") == "Текст статьи.")
        #expect(process("Спасибо за внимание. Вопросы?") == "Спасибо за внимание. Вопросы?")
    }

    @Test func collapsesDecoderLoops() {
        #expect(process("Да. Мы обсудили. Мы обсудили. Мы обсудили. Мы обсудили.") == "Да. Мы обсудили.")
        #expect(process("Нет. Нет.") == "Нет. Нет.")
    }
}
