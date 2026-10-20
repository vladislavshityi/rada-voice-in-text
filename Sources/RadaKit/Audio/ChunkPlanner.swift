/// Decides where to cut a long recording so chunks can be transcribed while
/// the user is still speaking.
///
/// Cuts land in natural pauses, so every chunk holds whole phrases and the
/// recognizer keeps full context for punctuation. Chunks stay under Whisper's
/// 30-second window.
public struct ChunkPlanner: Sendable {
    public var minimumSeconds: Double = 12
    public var maximumSeconds: Double = 28
    public var pauseSeconds: Double = 0.45

    private let sampleRate = AudioCapture.sampleRate
    private let frameLength = Int(AudioCapture.sampleRate * 0.02)

    public init() {}

    /// Number of leading samples to transcribe now, or `nil` to keep listening.
    public func cutLength(in samples: [Float]) -> Int? {
        let minimum = Int(minimumSeconds * sampleRate)
        let maximum = Int(maximumSeconds * sampleRate)
        guard samples.count >= minimum else { return nil }

        let energies = frameEnergies(samples)
        let quiet = quietThreshold(energies)
        let pauseFrames = Int(pauseSeconds * sampleRate) / frameLength
        let minimumFrame = minimum / frameLength
        let maximumFrame = min(maximum / frameLength, energies.count)

        // First sufficiently long pause after the minimum length.
        var runStart: Int?
        for frame in 0..<energies.count {
            if energies[frame] < quiet {
                if runStart == nil { runStart = frame }
                let start = runStart!
                let middle = (start + frame) / 2
                if frame - start + 1 >= pauseFrames, middle >= minimumFrame, middle < maximumFrame {
                    return middle * frameLength
                }
            } else {
                runStart = nil
            }
        }

        guard samples.count >= maximum else { return nil }
        // No pause: cut at the quietest moment of the last few seconds.
        let searchStart = max(minimumFrame, maximumFrame - Int(6 * sampleRate) / frameLength)
        let quietest = (searchStart..<maximumFrame).min { energies[$0] < energies[$1] } ?? maximumFrame
        return quietest * frameLength
    }

    private func frameEnergies(_ samples: [Float]) -> [Float] {
        stride(from: 0, to: samples.count - frameLength + 1, by: frameLength).map { start in
            var sum: Float = 0
            for index in start..<(start + frameLength) { sum += samples[index] * samples[index] }
            return (sum / Float(frameLength)).squareRoot()
        }
    }

    /// Adapts to the room: a frame is quiet if it is close to the noise floor,
    /// but always well below the level of speech.
    private func quietThreshold(_ energies: [Float]) -> Float {
        let sorted = energies.sorted()
        func percentile(_ p: Double) -> Float { sorted[Int(Double(sorted.count - 1) * p)] }
        let speechLevel = percentile(0.9)
        return min(max(percentile(0.15) * 3, 0.004), speechLevel * 0.25)
    }
}
