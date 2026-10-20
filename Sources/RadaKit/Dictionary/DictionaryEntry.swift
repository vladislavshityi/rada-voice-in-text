import Foundation

/// A name or term the user wants transcribed exactly as written.
public struct DictionaryEntry: Identifiable, Codable, Hashable, Sendable {
    public enum Kind: String, CaseIterable, Identifiable, Codable, Sendable {
        case person, organization, place, term

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .person: "Имя"
            case .organization: "Организация"
            case .place: "Место"
            case .term: "Термин"
            }
        }

        public var symbol: String {
            switch self {
            case .person: "person"
            case .organization: "building.2"
            case .place: "mappin.and.ellipse"
            case .term: "text.book.closed"
            }
        }
    }

    public var id: UUID
    /// Canonical spelling, e.g. «Силуанов», «ВШЭ», «iPhone».
    public var term: String
    /// Comma-separated misrecognitions to replace with `term`, e.g. «сила ванов, Зельманов».
    public var variants: String
    public var kind: Kind

    public init(id: UUID = UUID(), term: String, variants: String = "", kind: Kind = .term) {
        self.id = id
        self.term = term
        self.variants = variants
        self.kind = kind
    }

    public var trimmedTerm: String { term.trimmingCharacters(in: .whitespacesAndNewlines) }

    public var cleanVariants: [String] {
        variants
            .split(whereSeparator: { $0 == "," || $0 == ";" || $0.isNewline })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.caseInsensitiveCompare(trimmedTerm) != .orderedSame }
    }
}
