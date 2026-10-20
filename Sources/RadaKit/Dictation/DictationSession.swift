/// One dictation: transcribes completed phrases while the user keeps speaking.
///
/// Recording continues into a `SampleBuffer`; every few hundred milliseconds the
/// session checks whether a natural pause allows cutting off a chunk. Chunks are
/// transcribed one after another in the background, so when recording stops only
/// the last few seconds remain — latency stays low regardless of dictation length.
actor DictationSession {
    /// Recordings shorter than this contain no words.
    static let minimumSpeechSamples = Int(AudioCapture.sampleRate * 0.3)

    private let engine: any TranscriptionEngine
    private let buffer: SampleBuffer
    private let request: TranscriptionRequest
    private let planner = ChunkPlanner()

    private var consumedSamples = 0
    private var transcripts: [String] = []
    private var queue: Task<Void, Error>?
    private var chunkTasks: [Task<Void, Error>] = []
    private var monitor: Task<Void, Never>?

    init(engine: any TranscriptionEngine, buffer: SampleBuffer, request: TranscriptionRequest) {
        self.engine = engine
        self.buffer = buffer
        self.request = request
    }

    func start() {
        monitor = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(300))
                cutChunkIfReady()
            }
        }
    }

    /// Transcribes the remaining audio and returns the raw text of the whole dictation.
    func finish() async throws -> String {
        monitor?.cancel()
        let remaining = buffer.samples(in: consumedSamples..<buffer.count)
        consumedSamples += remaining.count
        if remaining.count >= Self.minimumSpeechSamples {
            enqueue(remaining)
        }
        try await queue?.value
        return transcripts.filter { !$0.isEmpty }.joined(separator: " ")
    }

    func cancel() {
        monitor?.cancel()
        chunkTasks.forEach { $0.cancel() }
    }

    private func cutChunkIfReady() {
        let pending = buffer.samples(in: consumedSamples..<buffer.count)
        guard let length = planner.cutLength(in: pending) else { return }
        consumedSamples += length
        enqueue(Array(pending.prefix(length)))
    }

    /// Chunks run strictly in order; each one sees the text of the previous.
    private func enqueue(_ samples: [Float]) {
        let previous = queue
        let task = Task {
            try await previous?.value
            try Task.checkCancellation()
            var chunkRequest = request
            chunkRequest.precedingText = transcripts.last
            let text = try await engine.transcribe(samples, request: chunkRequest)
            transcripts.append(text)
        }
        queue = task
        chunkTasks.append(task)
    }
}
