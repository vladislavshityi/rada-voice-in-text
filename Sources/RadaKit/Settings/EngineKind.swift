public enum EngineKind: String, CaseIterable, Identifiable, Codable, Sendable {
    /// Whisper Large v3 Turbo running locally on the GPU (Metal).
    case whisper
    /// Apple's on-device dictation model (macOS 26+).
    case appleDictation

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .whisper: "Whisper Large v3 Turbo"
        case .appleDictation: "Диктовка Apple"
        }
    }
}
