import Synchronization

/// 16 kHz mono samples shared between the audio thread and transcription.
public final class SampleBuffer: Sendable {
    private let storage = Mutex<[Float]>([])

    public init() {}

    public var count: Int { storage.withLock { $0.count } }

    func append(_ samples: UnsafeBufferPointer<Float>) {
        storage.withLock { $0.append(contentsOf: samples) }
    }

    /// Copies samples in `range`, clamped to what has been recorded.
    func samples(in range: Range<Int>) -> [Float] {
        storage.withLock { buffer in
            let clamped = range.clamped(to: 0..<buffer.count)
            return Array(buffer[clamped])
        }
    }
}
