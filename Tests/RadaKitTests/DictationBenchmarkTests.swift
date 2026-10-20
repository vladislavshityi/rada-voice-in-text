import Foundation
import Testing
@testable import RadaKit

/// Real-time simulation of a one-minute dictation. Slow (~1 min), so it runs
/// only with `RADA_BENCHMARK=1 swift test -c release --filter Benchmark`.
struct DictationBenchmarkTests {
    private static let enabled = ProcessInfo.processInfo.environment["RADA_BENCHMARK"] == "1"
        && WhisperModel.largeV3Turbo.isInstalled
    private static let vadModel = URL(filePath: #filePath)
        .deletingLastPathComponent().appending(path: "../../Vendor/whisper/ggml-silero-vad.bin")

    @Test(.enabled(if: enabled))
    func streamingChunksKeepLatencyLow() async throws {
        let samples = try WhisperEngineTests.loadFixture("ru-long")
        let engine = WhisperEngine(modelURL: WhisperModel.largeV3Turbo.localURL, vadModelURL: Self.vadModel)
        try await engine.prepare()
        let request = TranscriptionRequest(language: .russian, vocabulary: ["Силуанов", "Набиуллина", "ВШЭ"])
        let processor = TextProcessor(dictionary: [], options: .init(voiceCommands: true))

        // Batch: transcribe everything after the user stops.
        let batchStart = ContinuousClock.now
        let batch = processor.process(try await engine.transcribe(samples, request: request))
        let batchLatency = ContinuousClock.now - batchStart

        // Streaming: feed audio in real time, transcribing at pauses.
        let buffer = SampleBuffer()
        let session = DictationSession(engine: engine, buffer: buffer, request: request)
        await session.start()
        let block = Int(AudioCapture.sampleRate / 10)
        for start in stride(from: 0, to: samples.count, by: block) {
            samples[start..<min(start + block, samples.count)].withUnsafeBufferPointer { buffer.append($0) }
            try await Task.sleep(for: .milliseconds(100))
        }
        let streamStart = ContinuousClock.now
        let streamed = processor.process(try await session.finish())
        let streamLatency = ContinuousClock.now - streamStart

        print("BATCH  latency \(batchLatency):\n\(batch)\n")
        print("STREAM latency \(streamLatency):\n\(streamed)\n")
        #expect(streamLatency < batchLatency)
        #expect(streamed.contains("Силуанов"))
    }
}
