import Foundation
import Observation
import OSLog

/// Runs the main scenario: hotkey → record → transcribe → process → insert.
@MainActor
@Observable
public final class DictationController {
    public enum Phase: Equatable {
        case idle
        case recording(since: Date)
        case transcribing
        case delivered(TextInserter.Outcome)
        case failed(DictationIssue)
        case cancelled
    }

    public private(set) var phase: Phase = .idle
    /// Live microphone level (0…1) while recording.
    public private(set) var level: Float = 0
    /// The most recent result, kept in memory only — never written to disk.
    public private(set) var lastTranscript: String?

    /// Notified on every phase change (drives the floating indicator).
    @ObservationIgnored public var onPhaseChange: ((Phase) -> Void)?

    private static let maximumDuration: Duration = .seconds(15 * 60)

    private let settings: AppSettings
    private let dictionary: DictionaryStore
    private let permissions: Permissions
    private let engines: EngineProvider
    private let capture = AudioCapture()
    private let inserter = TextInserter()
    private let log = Logger(subsystem: "app.rada", category: "dictation")

    @ObservationIgnored private var session: DictationSession?
    @ObservationIgnored private var sessionID = UUID()
    @ObservationIgnored private var isStarting = false
    @ObservationIgnored private var timers: [Task<Void, Never>] = []

    public init(settings: AppSettings, dictionary: DictionaryStore, permissions: Permissions, engines: EngineProvider) {
        self.settings = settings
        self.dictionary = dictionary
        self.permissions = permissions
        self.engines = engines

        capture.onLevel = { [weak self] level in self?.level = level }
        capture.onInterruption = { [weak self] in self?.handleMicrophoneLoss() }
    }

    public var isBusy: Bool {
        switch phase {
        case .recording, .transcribing: true
        default: false
        }
    }

    public var isRecording: Bool {
        if case .recording = phase { return true }
        return false
    }

    // MARK: - Commands

    /// Starts recording, or stops it and inserts the result.
    public func toggle() {
        switch phase {
        case .recording: stop()
        case .transcribing: break // A second press must never cause a second insertion.
        default: Task { await start() }
        }
    }

    /// Discards the current dictation without inserting anything.
    public func cancel() {
        guard isBusy else { return }
        sessionID = UUID()
        capture.stop()
        if let session { Task { await session.cancel() } }
        session = nil
        setPhase(.cancelled, resetAfter: .milliseconds(700))
    }

    // MARK: - Flow

    private func start() async {
        guard !isBusy, !isStarting else { return }
        isStarting = true
        defer { isStarting = false }
        let engine: any TranscriptionEngine
        do {
            engine = try engines.engine()
        } catch {
            return fail(error)
        }
        guard await ensureMicrophoneAccess() else { return }

        let buffer: SampleBuffer
        do {
            buffer = try capture.start()
        } catch {
            log.error("Capture failed: \(error.localizedDescription)")
            fail(.microphoneUnavailable)
            return
        }

        let id = UUID()
        sessionID = id
        let request = TranscriptionRequest(
            language: settings.language,
            vocabulary: dictionary.activeEntries.map(\.trimmedTerm)
        )
        let session = DictationSession(engine: engine, buffer: buffer, request: request)
        self.session = session
        await session.start()

        if settings.soundsEnabled { SoundEffects.recordingStarted() }
        setPhase(.recording(since: .now))

        // Load the model while the user speaks, so it is warm when they stop.
        Task { try? await engine.prepare() }
        schedule(after: Self.maximumDuration) { [weak self] in
            guard let self, self.sessionID == id, self.isRecording else { return }
            self.stop()
        }
    }

    private func stop() {
        guard isRecording, let session else { return }
        capture.stop()
        level = 0
        if settings.soundsEnabled { SoundEffects.recordingStopped() }
        setPhase(.transcribing)

        let id = sessionID
        let processor = TextProcessor(
            dictionary: dictionary.activeEntries,
            options: .init(voiceCommands: settings.voiceCommandsEnabled)
        )
        Task {
            do {
                let raw = try await session.finish()
                guard id == sessionID else { return }
                let text = processor.process(raw)
                guard !text.isEmpty else { return fail(.nothingRecognized) }
                deliver(text)
            } catch TranscriptionError.cancelled {
                return
            } catch TranscriptionError.modelNotInstalled {
                guard id == sessionID else { return }
                fail(.modelMissing)
            } catch {
                guard id == sessionID else { return }
                log.error("Transcription failed: \(error.localizedDescription)")
                fail(.transcriptionFailed(error.localizedDescription))
            }
        }
    }

    private func deliver(_ text: String) {
        session = nil
        lastTranscript = text
        let outcome = inserter.deliver(text, mode: settings.insertionMode, smartSpacing: settings.smartSpacingEnabled)
        let lingering: Duration = outcome == .inserted ? .milliseconds(1200) : .seconds(4)
        setPhase(.delivered(outcome), resetAfter: lingering)
    }

    private func fail(_ issue: DictationIssue) {
        session = nil
        setPhase(.failed(issue), resetAfter: .seconds(4))
    }

    private func handleMicrophoneLoss() {
        guard isRecording else { return }
        cancel()
        fail(.microphoneDisconnected)
    }

    // MARK: - Helpers

    private func ensureMicrophoneAccess() async -> Bool {
        permissions.refresh()
        switch permissions.microphone {
        case .granted:
            return true
        case .notDetermined:
            if await permissions.requestMicrophone() { return true }
        case .denied:
            break
        }
        fail(.microphoneDenied)
        return false
    }

    private func setPhase(_ newPhase: Phase, resetAfter delay: Duration? = nil) {
        timers.forEach { $0.cancel() }
        timers.removeAll()
        phase = newPhase
        onPhaseChange?(newPhase)
        guard let delay else { return }
        schedule(after: delay) { [weak self] in
            guard let self, self.phase == newPhase else { return }
            self.setPhase(.idle)
        }
    }

    private func schedule(after delay: Duration, _ action: @escaping @MainActor () -> Void) {
        timers.append(Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            action()
        })
    }
}
