@preconcurrency import AVFoundation
import Foundation
import Speech
import Synchronization

/// Apple's on-device dictation model (SpeechAnalyzer + DictationTranscriber).
///
/// Fast and built into the system, but for Russian it currently returns text
/// without punctuation, so Whisper is the default engine.
@available(macOS 26, *)
public final class AppleDictationEngine: TranscriptionEngine {
    private let currentAnalyzer = Mutex<SpeechAnalyzer?>(nil)

    public init() {}

    public func prepare() async throws {}

    public func transcribe(_ samples: [Float], request: TranscriptionRequest) async throws -> String {
        guard !samples.isEmpty else { return "" }
        let transcriber = try await Self.transcriber(for: request.language)
        guard await AssetInventory.status(forModules: [transcriber]) == .installed else {
            throw TranscriptionError.languageAssetsMissing(request.language.title)
        }

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        currentAnalyzer.withLock { $0 = analyzer }
        defer { currentAnalyzer.withLock { $0 = nil } }

        if !request.vocabulary.isEmpty {
            let context = AnalysisContext()
            context.contextualStrings[.general] = request.vocabulary
            try await analyzer.setContext(context)
        }

        let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
        let buffer = try Self.makeBuffer(samples, convertedTo: format)
        let (input, continuation) = AsyncStream.makeStream(of: AnalyzerInput.self)

        async let collected = transcriber.results.reduce(into: "") { text, result in
            text += String(result.text.characters)
        }
        try await analyzer.start(inputSequence: input)
        continuation.yield(AnalyzerInput(buffer: buffer))
        continuation.finish()
        try await analyzer.finalizeAndFinishThroughEndOfInput()
        return try await collected.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func cancel() {
        guard let analyzer = currentAnalyzer.withLock({ $0 }) else { return }
        Task { await analyzer.cancelAndFinishNow() }
    }

    // MARK: - Language assets

    public static func assetStatus(for language: RecognitionLanguage) async -> AssetInventory.Status {
        guard let transcriber = try? await transcriber(for: language) else { return .unsupported }
        return await AssetInventory.status(forModules: [transcriber])
    }

    /// Downloads the language model from Apple. Called only on explicit user request.
    public static func installAssets(for language: RecognitionLanguage) async throws {
        let transcriber = try await transcriber(for: language)
        try await AssetInventory.assetInstallationRequest(supporting: [transcriber])?.downloadAndInstall()
    }

    private static func transcriber(for language: RecognitionLanguage) async throws -> DictationTranscriber {
        guard let locale = await DictationTranscriber.supportedLocale(equivalentTo: language.appleLocale) else {
            throw TranscriptionError.languageNotSupported(language.title)
        }
        return DictationTranscriber(locale: locale, preset: .longDictation)
    }

    private static func makeBuffer(_ samples: [Float], convertedTo format: AVAudioFormat?) throws -> AVAudioPCMBuffer {
        let sourceFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32, sampleRate: AudioCapture.sampleRate, channels: 1, interleaved: false
        )!
        guard let source = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: AVAudioFrameCount(samples.count)) else {
            throw TranscriptionError.failed("не удалось подготовить аудио")
        }
        source.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { source.floatChannelData![0].update(from: $0.baseAddress!, count: samples.count) }

        guard let format, format != sourceFormat else { return source }
        guard
            let converter = AVAudioConverter(from: sourceFormat, to: format),
            let output = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: AVAudioFrameCount(Double(samples.count) * format.sampleRate / sourceFormat.sampleRate) + 64
            )
        else { throw TranscriptionError.failed("неподдерживаемый формат аудио") }

        var consumed = false
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            if consumed {
                status.pointee = .endOfStream
                return nil
            }
            consumed = true
            status.pointee = .haveData
            return source
        }
        if let error { throw error }
        return output
    }
}
