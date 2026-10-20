import AVFoundation
import Foundation
import Testing
@testable import RadaKit

struct FileTranscriptionTests {
    private static let fixtures = URL(filePath: #filePath).deletingLastPathComponent().appending(path: "Fixtures")
    private static let vadModel = URL(filePath: #filePath)
        .deletingLastPathComponent().appending(path: "../../Vendor/whisper/ggml-silero-vad.bin")

    @Test func decodesWaveAtSixteenKilohertz() async throws {
        let url = Self.fixtures.appending(path: "ru-long.wav")
        let decoded = try await AudioFileDecoder.decode(url)
        let reference = try WhisperEngineTests.loadFixture("ru-long")
        #expect(abs(decoded.count - reference.count) < 160)
        #expect(try await AudioFileDecoder.duration(of: url) > 56)
    }

    @Test func decodesCompressedStereoAudio() async throws {
        // AAC, 44.1 kHz stereo — like a voice memo or a podcast download.
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = try WhisperEngineTests.loadFixture("ru-short")
        let url = directory.appending(path: "memo.m4a")
        try Self.writeStereoAAC(source, to: url)

        let decoded = try await AudioFileDecoder.decode(url)
        let expected = Double(source.count)
        #expect(abs(Double(decoded.count) - expected) / expected < 0.02)
        #expect(decoded.contains { abs($0) > 0.01 })
    }

    @Test func rejectsFilesWithoutAudio() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).txt")
        try "не звук".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }
        await #expect(throws: (any Error).self) { try await AudioFileDecoder.decode(url) }
    }

    @Test func segmentsCoverRecordingAndFitWhisperWindow() throws {
        let samples = try WhisperEngineTests.loadFixture("ru-long")
        let segments = FileTranscriber().segments(for: samples)
        #expect(segments.count >= 2)
        #expect(segments.first?.range.lowerBound == 0)
        #expect(segments.last?.range.upperBound == samples.count)
        for (previous, next) in zip(segments, segments.dropFirst()) {
            #expect(previous.range.upperBound == next.range.lowerBound)
        }
        #expect(segments.allSatisfy { $0.range.count <= Int(28 * AudioCapture.sampleRate) })
    }

    @Test func longSilenceStartsParagraph() {
        let rate = Int(AudioCapture.sampleRate)
        func speech(_ seconds: Int) -> [Float] {
            (0..<seconds * rate).map { sin(Float($0) * 0.05) * 0.3 * (0.6 + 0.4 * sin(Float($0) / 900)) }
        }
        let silence = [Float](repeating: 0, count: 3 * rate)
        let samples = speech(20) + silence + speech(20)
        let segments = FileTranscriber().segments(for: samples)
        #expect(segments.count == 2)
        #expect(segments.last?.startsParagraph == true)
    }

    @Test func rendersTimestamps() {
        let transcript = FileTranscript(paragraphs: [
            .init(start: 0, raw: "первый абзац"),
            .init(start: 3725, raw: "второй абзац"),
        ])
        let processor = TextProcessor(dictionary: [], options: .init(voiceCommands: false))
        #expect(transcript.render(with: processor, timestamps: false) == "Первый абзац.\n\nВторой абзац.")
        #expect(transcript.render(with: processor, timestamps: true) == "[00:00] Первый абзац.\n\n[1:02:05] Второй абзац.")
    }

    @Test(.enabled(if: WhisperModel.largeV3Turbo.isInstalled))
    func transcribesFileEndToEnd() async throws {
        let samples = try await AudioFileDecoder.decode(Self.fixtures.appending(path: "ru-long.wav"))
        let engine = WhisperEngine(modelURL: WhisperModel.largeV3Turbo.localURL, vadModelURL: Self.vadModel)
        let request = TranscriptionRequest(language: .russian, vocabulary: ["Силуанов", "Набиуллина", "ВШЭ"])
        let start = ContinuousClock.now
        let transcript = try await FileTranscriber().transcribe(samples, engine: engine, request: request) { _, _ in }
        let text = transcript.render(with: TextProcessor(dictionary: [], options: .init(voiceCommands: false)), timestamps: true)
        print("FILE (\(ContinuousClock.now - start)):\n\(text)")
        #expect(text.count > 400)
        #expect(text.contains("Набиуллин"))
    }

    @Test(.enabled(if: WhisperModel.largeV3Turbo.isInstalled))
    func cancellingOneCallLeavesOthersRunning() async throws {
        let samples = try WhisperEngineTests.loadFixture("ru-short")
        let engine = WhisperEngine(modelURL: WhisperModel.largeV3Turbo.localURL, vadModelURL: Self.vadModel)
        let request = TranscriptionRequest(language: .russian, vocabulary: [])
        let cancelled = Task { try await engine.transcribe(samples, request: request) }
        let kept = Task { try await engine.transcribe(samples, request: request) }
        cancelled.cancel()
        await #expect(throws: TranscriptionError.self) { try await cancelled.value }
        #expect(try await kept.value.contains("Захаров"))
    }

    private static func writeStereoAAC(_ mono: [Float], to url: URL) throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
        let source = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false)!
        let input = AVAudioPCMBuffer(pcmFormat: source, frameCapacity: AVAudioFrameCount(mono.count))!
        input.frameLength = input.frameCapacity
        mono.withUnsafeBufferPointer { input.floatChannelData![0].update(from: $0.baseAddress!, count: mono.count) }

        let converter = AVAudioConverter(from: source, to: format)!
        let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(Double(mono.count) * 44_100 / 16_000) + 1024)!
        var consumed = false
        try converter.convert(to: output, error: nil) { _, status in
            if consumed { status.pointee = .endOfStream; return nil }
            consumed = true
            status.pointee = .haveData
            return input
        }.throwIfError()

        let file = try AVAudioFile(forWriting: url, settings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44_100, AVNumberOfChannelsKey: 2,
        ])
        try file.write(from: output)
    }
}

private extension AVAudioConverterOutputStatus {
    func throwIfError() throws {
        if self == .error { throw TranscriptionError.failed("conversion") }
    }
}
