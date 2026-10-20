import CWhisper
import Foundation
import OSLog
import Synchronization

/// Whisper (whisper.cpp) running fully on-device with Metal acceleration.
///
/// The model stays in memory between dictations and is released after a
/// period of inactivity. All whisper.cpp calls happen on one serial queue, so
/// dictation and file transcription can share one model without doubling memory.
public final class WhisperEngine: TranscriptionEngine, @unchecked Sendable {
    /// Unload the model after this much inactivity to give memory back.
    private static let idleUnloadDelay: TimeInterval = 10 * 60
    private static let promptCharacterBudget = 600

    private let modelURL: URL
    private let vadModelURL: URL?
    private let queue = DispatchQueue(label: "app.rada.whisper", qos: .userInitiated)
    private let log = Logger(subsystem: "app.rada", category: "whisper")

    // Accessed only on `queue`.
    private var context: OpaquePointer?
    private var unloadWork: DispatchWorkItem?

    public init(modelURL: URL, vadModelURL: URL?) {
        self.modelURL = modelURL
        self.vadModelURL = vadModelURL
    }

    deinit {
        if let context { whisper_free(context) }
    }

    public func prepare() async throws {
        try await perform { _ = try self.loadedContext() }
    }

    /// Cancelling the calling task aborts only this call, not other work queued on the model.
    public func transcribe(_ samples: [Float], request: TranscriptionRequest) async throws -> String {
        let abortFlag = AbortFlag()
        return try await withTaskCancellationHandler {
            try await perform {
                if abortFlag.isRaised { throw TranscriptionError.cancelled }
                let context = try self.loadedContext()
                return try self.run(context, samples: samples, request: request, abortFlag: abortFlag)
            }
        } onCancel: {
            abortFlag.raise()
        }
    }

    // MARK: - Queue

    private func perform<T: Sendable>(_ work: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                self.unloadWork?.cancel()
                continuation.resume(with: Result(catching: work))
                self.scheduleUnload()
            }
        }
    }

    private func loadedContext() throws -> OpaquePointer {
        if let context { return context }
        guard FileManager.default.fileExists(atPath: modelURL.path) else { throw TranscriptionError.modelNotInstalled }

        var parameters = whisper_context_default_params()
        parameters.use_gpu = true
        parameters.flash_attn = true
        let start = ContinuousClock.now
        guard let loaded = whisper_init_from_file_with_params(modelURL.path, parameters) else {
            throw TranscriptionError.modelLoadFailed
        }
        log.info("Model loaded in \(ContinuousClock.now - start)")
        context = loaded
        return loaded
    }

    private func scheduleUnload() {
        let work = DispatchWorkItem { [weak self] in
            guard let self, let context = self.context else { return }
            whisper_free(context)
            self.context = nil
            self.log.info("Model unloaded after inactivity")
        }
        unloadWork = work
        queue.asyncAfter(deadline: .now() + Self.idleUnloadDelay, execute: work)
    }

    // MARK: - Inference

    private func run(
        _ context: OpaquePointer, samples: [Float], request: TranscriptionRequest, abortFlag: AbortFlag
    ) throws -> String {
        var parameters = whisper_full_default_params(WHISPER_SAMPLING_BEAM_SEARCH)
        parameters.beam_search.beam_size = 5
        parameters.n_threads = Int32(min(8, max(2, ProcessInfo.processInfo.activeProcessorCount - 2)))
        parameters.no_context = true
        parameters.no_timestamps = false
        parameters.print_progress = false
        parameters.print_realtime = false
        parameters.print_special = false
        parameters.print_timestamps = false
        parameters.suppress_blank = true
        parameters.suppress_nst = true
        parameters.temperature = 0
        parameters.temperature_inc = 0.2
        parameters.abort_callback = { userData in
            guard let userData else { return false }
            return Unmanaged<AbortFlag>.fromOpaque(userData).takeUnretainedValue().isRaised
        }
        parameters.abort_callback_user_data = Unmanaged.passUnretained(abortFlag).toOpaque()

        let language = request.language.whisperCode ?? "auto"
        let prompt = Self.prompt(for: request)
        let vadPath = vadModelURL?.path
        let start = ContinuousClock.now

        let status: Int32 = language.withCString { languagePointer in
            withOptionalCString(prompt) { promptPointer in
                withOptionalCString(vadPath) { vadPointer in
                    parameters.language = languagePointer
                    parameters.detect_language = false
                    parameters.initial_prompt = promptPointer
                    if let vadPointer {
                        // Silero VAD strips silence: faster and no hallucinations on quiet audio.
                        parameters.vad = true
                        parameters.vad_model_path = vadPointer
                        parameters.vad_params = whisper_vad_default_params()
                    }
                    return samples.withUnsafeBufferPointer { buffer in
                        whisper_full(context, parameters, buffer.baseAddress, Int32(buffer.count))
                    }
                }
            }
        }

        if abortFlag.isRaised { throw TranscriptionError.cancelled }
        guard status == 0 else { throw TranscriptionError.failed("whisper_full вернул \(status)") }

        let text = (0..<whisper_full_n_segments(context))
            .compactMap { whisper_full_get_segment_text(context, $0).map { String(cString: $0) } }
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let audioSeconds = Double(samples.count) / AudioCapture.sampleRate
        log.info("Transcribed \(audioSeconds, format: .fixed(precision: 1))s in \(ContinuousClock.now - start)")
        return text
    }

    /// Whisper's prompt conditions spelling and style: dictionary terms teach it
    /// names, the tail of the previous chunk keeps punctuation consistent.
    static func prompt(for request: TranscriptionRequest) -> String? {
        var parts: [String] = []
        var budget = promptCharacterBudget
        if let preceding = request.precedingText, !preceding.isEmpty {
            let tail = String(preceding.suffix(200))
            budget -= tail.count
            parts.append(tail)
        }
        var terms: [String] = []
        for term in request.vocabulary {
            guard budget - term.count - 2 > 0 else { break }
            budget -= term.count + 2
            terms.append(term)
        }
        if !terms.isEmpty {
            parts.insert(terms.joined(separator: ", ") + ".", at: 0)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }
}

/// Cancellation flag polled by whisper.cpp between compute steps.
private final class AbortFlag: Sendable {
    private let value = Atomic<Bool>(false)

    var isRaised: Bool { value.load(ordering: .relaxed) }
    func raise() { value.store(true, ordering: .relaxed) }
}

private func withOptionalCString<Result>(
    _ string: String?, _ body: (UnsafePointer<CChar>?) throws -> Result
) rethrows -> Result {
    guard let string else { return try body(nil) }
    return try string.withCString { try body($0) }
}
