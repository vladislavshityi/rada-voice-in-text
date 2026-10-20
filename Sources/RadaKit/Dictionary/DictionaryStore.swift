import Foundation
import Observation
import OSLog

/// The user's custom dictionary, persisted as JSON in Application Support.
@MainActor
@Observable
public final class DictionaryStore {
    public var entries: [DictionaryEntry] = [] {
        didSet { scheduleSave() }
    }

    /// Entries ready for recognition and correction (blank terms skipped).
    public var activeEntries: [DictionaryEntry] {
        entries.filter { !$0.trimmedTerm.isEmpty }
    }

    private let fileURL: URL
    private var saveTask: Task<Void, Never>?
    private let log = Logger(subsystem: "app.rada", category: "dictionary")

    public init(fileURL: URL = AppPaths.dictionary) {
        self.fileURL = fileURL
        entries = load()
    }

    @discardableResult
    public func add(_ entry: DictionaryEntry = DictionaryEntry(term: "")) -> DictionaryEntry {
        entries.insert(entry, at: 0)
        return entry
    }

    public func remove(id: DictionaryEntry.ID) {
        entries.removeAll { $0.id == id }
    }

    public func removeAll() {
        entries = []
        saveTask?.cancel()
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func load() -> [DictionaryEntry] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        do {
            return try JSONDecoder().decode([DictionaryEntry].self, from: data)
        } catch {
            log.error("Dictionary file is unreadable: \(error.localizedDescription)")
            return []
        }
    }

    /// Coalesces rapid edits (typing) into a single write.
    private func scheduleSave() {
        saveTask?.cancel()
        let snapshot = entries
        let url = fileURL
        saveTask = Task { [log] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            do {
                try AppPaths.ensureDirectory(url.deletingLastPathComponent())
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                try encoder.encode(snapshot).write(to: url, options: .atomic)
            } catch {
                log.error("Dictionary save failed: \(error.localizedDescription)")
            }
        }
    }
}
