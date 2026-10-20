import AVFoundation
import Foundation
import Testing
@testable import RadaKit

/// End-to-end check on real audio. Runs only when the model is installed locally.
struct WhisperEngineTests {
    private static let model = WhisperModel.largeV3Turbo
    private static let vadModel = URL(filePath: #filePath)
        .deletingLastPathComponent().appending(path: "../../Vendor/whisper/ggml-silero-vad.bin")

    @Test(.enabled(if: model.isInstalled))
    func transcribesRussianWithPunctuation() async throws {
        let engine = WhisperEngine(modelURL: Self.model.localURL, vadModelURL: Self.vadModel)
        let samples = try Self.loadFixture("ru-short")
        let request = TranscriptionRequest(language: .russian, vocabulary: ["Захарова"])
        let raw = try await engine.transcribe(samples, request: request)
        let text = TextProcessor(dictionary: [], options: .init(voiceCommands: true)).process(raw)
        #expect(text == "Привет, как дела? Я сегодня ездила в редакцию, а потом встретилась с Марией Захаровой. Мы обсудили интервью.")
    }

    @Test(.enabled(if: model.isInstalled))
    func silenceProducesNoText() async throws {
        let engine = WhisperEngine(modelURL: Self.model.localURL, vadModelURL: Self.vadModel)
        let noise = (0..<16_000 * 4).map { _ in Float.random(in: -0.002...0.002) }
        let raw = try await engine.transcribe(noise, request: .init(language: .russian, vocabulary: []))
        #expect(TextProcessor(dictionary: [], options: .init(voiceCommands: true)).process(raw).isEmpty)
    }

    static func loadFixture(_ name: String) throws -> [Float] {
        let url = URL(filePath: #filePath).deletingLastPathComponent().appending(path: "Fixtures/\(name).wav")
        let file = try AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false)
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)))
        try file.read(into: buffer)
        return Array(UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength)))
    }
}
