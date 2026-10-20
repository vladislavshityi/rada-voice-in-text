import Foundation

/// The recognized text of a file, kept as paragraphs with their start times.
public struct FileTranscript: Sendable, Equatable {
    public struct Paragraph: Sendable, Equatable {
        /// Offset of the paragraph in the file, in seconds.
        public var start: TimeInterval
        /// Recognizer output before text processing.
        public var raw: String
    }

    public var paragraphs: [Paragraph] = []

    public init(paragraphs: [Paragraph] = []) {
        self.paragraphs = paragraphs
    }

    /// Processes every paragraph and joins them, optionally with `[mm:ss]` marks.
    public func render(with processor: TextProcessor, timestamps: Bool) -> String {
        paragraphs.compactMap { paragraph in
            let text = processor.process(paragraph.raw)
            guard !text.isEmpty else { return nil }
            return timestamps ? "[\(Self.timestamp(paragraph.start))] \(text)" : text
        }
        .joined(separator: "\n\n")
    }

    static func timestamp(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.down))
        let (hours, minutes, secs) = (total / 3600, total / 60 % 60, total % 60)
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%02d:%02d", minutes, secs)
    }
}

/// Transcribes a long recording piece by piece.
///
/// The audio is cut in natural pauses into pieces that fit Whisper's 30-second
/// window, exactly like a long dictation. A long pause starts a new paragraph,
/// so interviews come out readable rather than as one block of text.
public struct FileTranscriber: Sendable {
    public struct Segment: Equatable, Sendable {
        public var range: Range<Int>
        public var startsParagraph: Bool
    }

    /// Silence this long between phrases starts a new paragraph.
    static let paragraphPause: Double = 1.2

    private let planner = ChunkPlanner()
    private let sampleRate = AudioCapture.sampleRate

    public init() {}

    /// Splits the whole recording into consecutive pieces covering every sample.
    public func segments(for samples: [Float]) -> [Segment] {
        let maximum = Int(planner.maximumSeconds * sampleRate)
        let context = Int(4 * sampleRate)
        var result: [Segment] = []
        var offset = 0
        var startsParagraph = true

        while offset < samples.count {
            let remaining = samples.count - offset
            guard remaining > maximum else {
                result.append(Segment(range: offset..<samples.count, startsParagraph: startsParagraph))
                break
            }
            let window = Array(samples[offset..<(offset + maximum)])
            let length = max(planner.cutLength(in: window) ?? maximum, 1)
            let cut = offset + length
            result.append(Segment(range: offset..<cut, startsParagraph: startsParagraph))

            // Judge the pause from audio on both sides of the cut.
            let around = max(cut - context, 0)..<min(cut + context, samples.count)
            startsParagraph = planner.pauseLength(at: cut - around.lowerBound, in: Array(samples[around])) >= Self.paragraphPause
            offset = cut
        }
        return result
    }

    /// Recognizes `samples` in order. `onUpdate` receives the text so far and
    /// how many seconds of audio have been processed.
    public func transcribe(
        _ samples: [Float],
        engine: any TranscriptionEngine,
        request: TranscriptionRequest,
        onUpdate: @escaping @Sendable (FileTranscript, TimeInterval) -> Void
    ) async throws -> FileTranscript {
        var transcript = FileTranscript()
        var previous: String?

        for segment in segments(for: samples) {
            try Task.checkCancellation()
            let start = Double(segment.range.lowerBound) / sampleRate
            if segment.startsParagraph || transcript.paragraphs.isEmpty {
                transcript.paragraphs.append(.init(start: start, raw: ""))
            }

            var text = ""
            if segment.range.count >= DictationSession.minimumSpeechSamples {
                var pieceRequest = request
                pieceRequest.precedingText = previous
                text = try await engine.transcribe(Array(samples[segment.range]), request: pieceRequest)
            }
            if !text.isEmpty {
                let last = transcript.paragraphs.count - 1
                transcript.paragraphs[last].raw += transcript.paragraphs[last].raw.isEmpty ? text : " " + text
                previous = text
            }
            onUpdate(transcript, Double(segment.range.upperBound) / sampleRate)
        }
        transcript.paragraphs.removeAll { $0.raw.isEmpty }
        return transcript
    }
}
