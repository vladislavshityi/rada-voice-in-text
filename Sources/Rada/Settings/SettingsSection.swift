enum SettingsSection: String, CaseIterable, Identifiable {
    case general, recognition, dictionary, privacy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "Основные"
        case .recognition: "Распознавание"
        case .dictionary: "Словарь"
        case .privacy: "Конфиденциальность"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .recognition: "waveform"
        case .dictionary: "character.book.closed"
        case .privacy: "lock.shield"
        }
    }
}
