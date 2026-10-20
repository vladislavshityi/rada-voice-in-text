@preconcurrency import AVFoundation
import OSLog

/// Records the default microphone, converting to 16 kHz mono Float32.
///
/// The microphone is open only between `start()` and `stop()`; nothing is written to disk.
public final class AudioCapture: @unchecked Sendable {
    public static let sampleRate: Double = 16_000

    public enum CaptureError: Error {
        case noInputDevice
        case converterUnavailable
    }

    /// Normalized input level (0…1), delivered on the main queue ~20 times per second.
    public var onLevel: (@MainActor (Float) -> Void)?
    /// Called on the main queue when recording cannot continue (microphone gone).
    public var onInterruption: (@MainActor () -> Void)?

    private let engine = AVAudioEngine()
    private let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false
    )!
    private var buffer: SampleBuffer?
    private var configurationObserver: NSObjectProtocol?
    private let log = Logger(subsystem: "app.rada", category: "audio")

    public init() {}

    /// Starts recording into a fresh buffer and returns it.
    public func start() throws -> SampleBuffer {
        let buffer = SampleBuffer()
        try capture(into: buffer)
        self.buffer = buffer

        // Bluetooth headsets switch profiles when the microphone opens, and devices
        // can change mid-recording: continue into the same buffer on the new device.
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.recoverFromConfigurationChange() }
        }
        return buffer
    }

    /// Stops recording and releases the microphone.
    public func stop() {
        if let configurationObserver {
            NotificationCenter.default.removeObserver(configurationObserver)
            self.configurationObserver = nil
        }
        buffer = nil
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        engine.reset()
    }

    @MainActor
    private func recoverFromConfigurationChange() {
        guard let buffer else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        do {
            try capture(into: buffer)
            log.info("Audio device changed; recording continues")
        } catch {
            log.error("Audio device lost: \(error.localizedDescription)")
            stop()
            onInterruption?()
        }
    }

    private func capture(into buffer: SampleBuffer) throws {
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else { throw CaptureError.noInputDevice }
        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw CaptureError.converterUnavailable
        }

        let meter = LevelMeter()
        let targetFormat = targetFormat
        let onLevel = onLevel

        input.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { [log] pcm, _ in
            let ratio = targetFormat.sampleRate / inputFormat.sampleRate
            let capacity = AVAudioFrameCount(Double(pcm.frameLength) * ratio) + 32
            guard let output = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }

            var consumed = false
            var error: NSError?
            converter.convert(to: output, error: &error) { _, status in
                if consumed {
                    status.pointee = .noDataNow
                    return nil
                }
                consumed = true
                status.pointee = .haveData
                return pcm
            }
            if let error {
                log.error("Audio conversion failed: \(error.localizedDescription)")
                return
            }
            guard let channel = output.floatChannelData?[0], output.frameLength > 0 else { return }
            let samples = UnsafeBufferPointer(start: channel, count: Int(output.frameLength))
            buffer.append(samples)

            if let level = meter.process(samples), let onLevel {
                DispatchQueue.main.async { MainActor.assumeIsolated { onLevel(level) } }
            }
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            throw error
        }
    }
}

/// Converts raw samples to a perceptual 0…1 level, throttled to ~20 Hz.
private final class LevelMeter: @unchecked Sendable {
    private var accumulated: Float = 0
    private var count = 0
    private let window = Int(AudioCapture.sampleRate / 20)

    func process(_ samples: UnsafeBufferPointer<Float>) -> Float? {
        for sample in samples { accumulated += sample * sample }
        count += samples.count
        guard count >= window else { return nil }
        let rms = (accumulated / Float(count)).squareRoot()
        accumulated = 0
        count = 0
        let decibels = 20 * log10(max(rms, 1e-6))
        return min(max((decibels + 55) / 45, 0), 1)
    }
}
