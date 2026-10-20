import Foundation
import Testing
@testable import RadaKit

struct ChunkPlannerTests {
    private let rate = Int(AudioCapture.sampleRate)

    private func speech(_ seconds: Double) -> [Float] {
        (0..<Int(seconds * Double(rate))).map { Float(sin(Double($0) * 0.05)) * 0.2 }
    }

    private func silence(_ seconds: Double) -> [Float] {
        Array(repeating: 0.0005, count: Int(seconds * Double(rate)))
    }

    @Test func waitsForMinimumLength() {
        #expect(ChunkPlanner().cutLength(in: speech(5) + silence(1)) == nil)
    }

    @Test func cutsInsidePauseAfterMinimum() throws {
        let audio = speech(13) + silence(0.8) + speech(3)
        let cut = try #require(ChunkPlanner().cutLength(in: audio))
        let seconds = Double(cut) / Double(rate)
        #expect(seconds > 13 && seconds < 13.8)
    }

    @Test func ignoresPausesBeforeMinimum() {
        #expect(ChunkPlanner().cutLength(in: speech(4) + silence(1) + speech(9)) == nil)
    }

    @Test func forcesCutWithoutPauses() throws {
        let cut = try #require(ChunkPlanner().cutLength(in: speech(29)))
        #expect(Double(cut) / Double(rate) <= 28)
    }
}
