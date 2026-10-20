/// Something that stopped a dictation, phrased for the user.
public enum DictationIssue: Error, Equatable, Sendable {
    case microphoneDenied
    case microphoneUnavailable
    case microphoneDisconnected
    case modelMissing
    case engineUnavailable
    case nothingRecognized
    case transcriptionFailed(String)

    public var title: String {
        switch self {
        case .microphoneDenied: "Нет доступа к микрофону"
        case .microphoneUnavailable: "Микрофон не найден"
        case .microphoneDisconnected: "Микрофон отключён"
        case .modelMissing: "Модель не загружена"
        case .engineUnavailable: "Движок недоступен"
        case .nothingRecognized: "Речь не распознана"
        case .transcriptionFailed: "Ошибка распознавания"
        }
    }

    public var message: String {
        switch self {
        case .microphoneDenied: "Разрешите доступ в Системных настройках"
        case .microphoneUnavailable: "Подключите микрофон и попробуйте снова"
        case .microphoneDisconnected: "Запись остановлена, текст не вставлен"
        case .modelMissing: "Загрузите модель в настройках Rada"
        case .engineUnavailable: "Диктовка Apple требует macOS 26"
        case .nothingRecognized: "Попробуйте говорить ближе к микрофону"
        case .transcriptionFailed(let reason): reason
        }
    }

    /// Where the user can fix the problem.
    public var settingsDestination: SettingsDestination? {
        switch self {
        case .microphoneDenied: .microphonePermission
        case .modelMissing, .engineUnavailable: .recognition
        default: nil
        }
    }

    public enum SettingsDestination: Sendable {
        case microphonePermission
        case recognition
    }
}
