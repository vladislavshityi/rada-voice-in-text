public enum InsertionMode: String, CaseIterable, Identifiable, Codable, Sendable {
    /// Paste at the cursor; requires Accessibility permission.
    case paste
    /// Only copy to the clipboard.
    case clipboard

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .paste: "Вставлять в позицию курсора"
        case .clipboard: "Только копировать в буфер"
        }
    }
}
