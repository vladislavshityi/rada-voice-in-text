import Foundation

public enum RecognitionLanguage: String, CaseIterable, Identifiable, Codable, Sendable {
    case russian
    case english
    case automatic

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .russian: "Русский"
        case .english: "English"
        case .automatic: "Автоопределение"
        }
    }

    /// Language code understood by Whisper; `nil` enables auto-detection.
    var whisperCode: String? {
        switch self {
        case .russian: "ru"
        case .english: "en"
        case .automatic: nil
        }
    }

    /// Apple's dictation needs a concrete locale; auto-detection falls back to Russian.
    var appleLocale: Locale {
        switch self {
        case .english: Locale(identifier: "en-US")
        case .russian, .automatic: Locale(identifier: "ru-RU")
        }
    }
}
