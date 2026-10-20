import Foundation
import Observation
import OSLog

/// Recognizes a recording chosen by the user: open → decode → transcribe.
///
/// Runs independently of dictation and shares its engine. The file is only
/// read; the result lives in memory until the user copies or saves it.
@MainActor
@Observable
public final class FileTranscriptionController {
    public enum Phase: Equatable {
        case idle
        case decoding(progress: Double)
        case transcribing(progress: Double)
        case finished
        case failed(String)
    }

    public private(set) var phase: Phase = .idle
    public private(set) var fileURL: URL?
    /// Length of the recording in seconds, once known.
    public private(set) var duration: TimeInterval?
    /// When recognition (not decoding) started, for the time estimate.
    public private(set) var transcriptionStartedAt: Date?
    /// The rendered text so far; grows while the file is being transcribed.
    public private(set) var text = ""

    private let settings: AppSettings
    private let dictionary: DictionaryStore
    private let engines: EngineProvider
    private let log = Logger(subsystem: "app.rada", category: "file")

    @ObservationIgnored private var transcript = FileTranscript()
    @ObservationIgnored private var job: Task<Void, Never>?
    /// Guards against late updates from a job that was already replaced.
    @ObservationIgnored private var jobID = UUID()

    public init(settings: AppSettings, dictionary: DictionaryStore, engines: EngineProvider) {
        self.settings = settings
        self.dictionary = dictionary
        self.engines = engines
    }

    public var isRunning: Bool {
        switch phase {
        case .decoding, .transcribing: true
        default: false
        }
    }

    public var includeTimestamps: Bool {
        get { settings.fileTimestampsEnabled }
        set {
            settings.fileTimestampsEnabled = newValue
            render()
        }
    }

    // MARK: - Commands

    public func transcribe(_ url: URL) {
        cancel()
        fileURL = url
        duration = nil
        transcriptionStartedAt = nil
        transcript = FileTranscript()
        text = ""

        let engine: any TranscriptionEngine
        do {
            engine = try engines.engine()
        } catch {
            phase = .failed(error.title + ". " + error.message)
            return
        }
        let request = TranscriptionRequest(
            language: settings.language,
            vocabulary: dictionary.activeEntries.map(\.trimmedTerm)
        )
        let id = UUID()
        jobID = id
        phase = .decoding(progress: 0)
        job = Task { await run(url, id: id, engine: engine, request: request) }
    }

    public func cancel() {
        jobID = UUID()
        job?.cancel()
        job = nil
        if isRunning { phase = .idle }
    }

    /// Forgets the file and its text.
    public func reset() {
        cancel()
        phase = .idle
        fileURL = nil
        duration = nil
        transcript = FileTranscript()
        text = ""
    }

    // MARK: - Flow

    private func run(_ url: URL, id: UUID, engine: any TranscriptionEngine, request: TranscriptionRequest) async {
        // A long file can take many minutes: keep the Mac from idle-sleeping meanwhile.
        let activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled], reason: "Расшифровка аудиофайла"
        )
        defer { ProcessInfo.processInfo.endActivity(activity) }

        do {
            duration = try await AudioFileDecoder.duration(of: url)
            let samples = try await AudioFileDecoder.decode(url) { progress in
                Task { @MainActor in
                    guard self.jobID == id, case .decoding = self.phase else { return }
                    self.phase = .decoding(progress: progress)
                }
            }
            try Task.checkCancellation()
            let total = Double(samples.count) / AudioCapture.sampleRate
            duration = total
            guard samples.count >= DictationSession.minimumSpeechSamples else { throw FileIssue.empty }

            Task { try? await engine.prepare() }
            transcriptionStartedAt = .now
            phase = .transcribing(progress: 0)
            let result = try await FileTranscriber().transcribe(samples, engine: engine, request: request) { partial, processed in
                Task { @MainActor in
                    guard self.jobID == id, case .transcribing = self.phase else { return }
                    self.transcript = partial
                    self.render()
                    self.phase = .transcribing(progress: total > 0 ? min(processed / total, 1) : 0)
                }
            }
            try Task.checkCancellation()
            guard jobID == id else { return }
            transcript = result
            render()
            guard !text.isEmpty else { throw FileIssue.nothingRecognized }
            phase = .finished
        } catch is CancellationError {
            return
        } catch TranscriptionError.cancelled {
            return
        } catch TranscriptionError.modelNotInstalled {
            fail(DictationIssue.modelMissing.title + ". " + DictationIssue.modelMissing.message)
        } catch {
            log.error("File transcription failed: \(error.localizedDescription)")
            fail(error.localizedDescription)
        }
    }

    private func fail(_ message: String) {
        guard !Task.isCancelled else { return }
        phase = .failed(message)
    }

    private func render() {
        let processor = TextProcessor(dictionary: dictionary.activeEntries, options: .init(voiceCommands: false))
        text = transcript.render(with: processor, timestamps: settings.fileTimestampsEnabled)
    }

    enum FileIssue: LocalizedError {
        case empty
        case nothingRecognized

        var errorDescription: String? {
            switch self {
            case .empty: "Файл пустой или слишком короткий."
            case .nothingRecognized: "Речь в файле не распознана. Проверьте язык распознавания в настройках."
            }
        }
    }
}
