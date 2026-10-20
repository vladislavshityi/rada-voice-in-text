@preconcurrency import AVFoundation

/// Reads the sound of an audio or video file as 16 kHz mono Float32.
///
/// Anything AVFoundation can open works: WAV, AIFF, MP3, M4A/AAC, FLAC, CAF,
/// voice memos and the audio track of MOV/MP4 video. All tracks are mixed down.
/// The file is only read; nothing is copied or written.
public enum AudioFileDecoder {
    /// Longer files would need too much memory (≈ 230 MB per hour of samples).
    public static let maximumDuration: TimeInterval = 3 * 60 * 60

    public enum DecodeError: LocalizedError {
        case unreadable
        case noAudioTrack
        case tooLong(TimeInterval)

        public var errorDescription: String? {
            switch self {
            case .unreadable:
                "Не удалось прочитать файл. Возможно, формат не поддерживается или файл повреждён."
            case .noAudioTrack:
                "В файле нет звуковой дорожки."
            case .tooLong:
                "Файл длиннее трёх часов. Разделите его на части и распознайте по очереди."
            }
        }
    }

    /// Duration of the file's audio in seconds.
    public static func duration(of url: URL) async throws -> TimeInterval {
        let asset = AVURLAsset(url: url)
        guard let tracks = try? await asset.loadTracks(withMediaType: .audio) else { throw DecodeError.unreadable }
        guard !tracks.isEmpty else { throw DecodeError.noAudioTrack }
        guard let duration = try? await asset.load(.duration), duration.isNumeric else { throw DecodeError.unreadable }
        return duration.seconds
    }

    /// Decodes the whole file. `onProgress` receives the share decoded so far (0…1).
    public static func decode(_ url: URL, onProgress: @escaping @Sendable (Double) -> Void = { _ in }) async throws -> [Float] {
        let asset = AVURLAsset(url: url)
        guard let tracks = try? await asset.loadTracks(withMediaType: .audio) else { throw DecodeError.unreadable }
        guard !tracks.isEmpty else { throw DecodeError.noAudioTrack }
        let duration = (try? await asset.load(.duration))?.seconds ?? 0
        guard duration <= maximumDuration else { throw DecodeError.tooLong(duration) }

        guard let reader = try? AVAssetReader(asset: asset) else { throw DecodeError.unreadable }
        let output = AVAssetReaderAudioMixOutput(audioTracks: tracks, audioSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: AudioCapture.sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ])
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw DecodeError.unreadable }
        reader.add(output)

        return try await Task.detached(priority: .userInitiated) {
            guard reader.startReading() else { throw DecodeError.unreadable }
            defer { reader.cancelReading() }

            var samples: [Float] = []
            samples.reserveCapacity(Int(duration * AudioCapture.sampleRate) + 1)
            var reported = 0.0
            while let buffer = output.copyNextSampleBuffer() {
                try Task.checkCancellation()
                append(buffer, to: &samples)
                if duration > 0 {
                    let progress = min(Double(samples.count) / AudioCapture.sampleRate / duration, 1)
                    if progress - reported >= 0.01 {
                        reported = progress
                        onProgress(progress)
                    }
                }
            }
            guard reader.status == .completed else { throw DecodeError.unreadable }
            return samples
        }.value
    }

    private static func append(_ sampleBuffer: CMSampleBuffer, to samples: inout [Float]) {
        guard let block = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }
        let length = CMBlockBufferGetDataLength(block)
        let count = length / MemoryLayout<Float>.size
        guard count > 0 else { return }
        let start = samples.count
        samples.append(contentsOf: repeatElement(0, count: count))
        samples.withUnsafeMutableBytes { bytes in
            let destination = bytes.baseAddress!.advanced(by: start * MemoryLayout<Float>.size)
            _ = CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: count * MemoryLayout<Float>.size, destination: destination)
        }
    }
}
