import Foundation

public struct TranscriptionRequest: Sendable {
    public var language: RecognitionLanguage
    /// Dictionary terms used to bias recognition toward correct spelling.
    public var vocabulary: [String]
    /// Text of the previous chunk of the same dictation, for continuity.
    public var precedingText: String?

    public init(language: RecognitionLanguage, vocabulary: [String], precedingText: String? = nil) {
        self.language = language
        self.vocabulary = vocabulary
        self.precedingText = precedingText
    }
}

/// A local speech-to-text engine working on 16 kHz mono samples.
public protocol TranscriptionEngine: Sendable {
    /// Loads models ahead of time; called when recording starts.
    func prepare() async throws
    /// Cancelling the calling task aborts this call as soon as possible
    /// and throws `TranscriptionError.cancelled`.
    func transcribe(_ samples: [Float], request: TranscriptionRequest) async throws -> String
}

public enum TranscriptionError: LocalizedError {
    case modelNotInstalled
    case modelLoadFailed
    case languageNotSupported(String)
    case languageAssetsMissing(String)
    case requiresNewerSystem
    case cancelled
    case failed(String)

    public var errorDescription: String? {
        switch self {
        case .modelNotInstalled:
            "Модель распознавания не загружена. Откройте настройки → Распознавание."
        case .modelLoadFailed:
            "Не удалось загрузить модель распознавания. Попробуйте загрузить её заново."
        case .languageNotSupported(let language):
            "Язык «\(language)» не поддерживается локальным распознаванием."
        case .languageAssetsMissing(let language):
            "Языковые ресурсы «\(language)» не установлены. Установите их в настройках."
        case .requiresNewerSystem:
            "Диктовка Apple доступна в macOS 26 и новее."
        case .cancelled:
            "Распознавание отменено."
        case .failed(let reason):
            "Ошибка распознавания: \(reason)"
        }
    }
}
