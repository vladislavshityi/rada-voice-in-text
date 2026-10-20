import Combine
import Foundation

/// A single rendered moment: the pose plus time-based phases.
struct MascotFrame {
    var pose: MascotPose
    var swirlPhase: CGFloat
    var time: TimeInterval
}

/// Turns mood and voice level into a continuously living pose: breathing,
/// blinking, wandering gaze, voice-driven pulsing and smooth mood transitions.
///
/// It is an `ObservableObject` only so a view can own it with `@StateObject`;
/// it publishes nothing because the timeline already redraws every frame.
final class MascotAnimator: ObservableObject {
    private var pose = MascotPose()
    private var swirlPhase: CGFloat = 0
    private var lastTime: TimeInterval?
    private var mood: MascotMood?
    private var moodStart: TimeInterval = 0
    private var level: CGFloat = 0
    private var nextBlink: TimeInterval = 0
    private var blinkStart: TimeInterval?

    private static let blinkDuration: TimeInterval = 0.17

    func frame(at time: TimeInterval, mood: MascotMood, level rawLevel: CGFloat, reduceMotion: Bool) -> MascotFrame {
        let dt = CGFloat(min(max(time - (lastTime ?? time), 0), 0.1))
        lastTime = time
        if mood != self.mood {
            self.mood = mood
            moodStart = time
            if nextBlink == 0 { nextBlink = time + 1.5 }
        }

        // Fast attack, slow release: the sphere reacts instantly to the voice and calms down gently.
        let response: CGFloat = rawLevel > level ? 20 : 5
        level += (rawLevel - level) * (1 - exp(-dt * response))

        let target = targetPose(at: time, mood: mood, reduceMotion: reduceMotion)
        pose = pose.blended(toward: target, amount: 1 - exp(-dt * 9))
        swirlPhase += dt * pose.swirlSpeed

        var output = pose
        output.eyeOpenness *= blinkFactor(at: time, mood: mood)
        output.hop = target.hop
        output.shake = target.shake
        return MascotFrame(pose: output, swirlPhase: swirlPhase, time: time)
    }

    private func targetPose(at time: TimeInterval, mood: MascotMood, reduceMotion: Bool) -> MascotPose {
        var target = MascotPose.base(for: mood)
        let elapsed = time - moodStart
        let breath = CGFloat(sin(time * 2 * .pi / 4.2))
        let motion: CGFloat = reduceMotion ? 0.3 : 1

        target.scale += 0.022 * breath * motion
        switch mood {
        case .idle:
            target.lookX += CGFloat(0.28 * sin(time * 0.43) + 0.1 * sin(time * 1.27)) * motion
            target.lookY += CGFloat(0.14 * sin(time * 0.37 + 1.1)) * motion
        case .listening:
            target.scale += level * 0.09
            target.wobble += level * 0.05 * motion
            target.swirlSpeed += level * 2.6
            target.energy += level * 0.25
            target.eyeScale += level * 0.06
            target.lookX += CGFloat(0.06 * sin(time * 0.8))
            target.hop = -level * 0.035 * motion
        case .thinking:
            target.lookX += CGFloat(0.08 * sin(time * 1.6))
        case .happy:
            // A single cheerful hop right after success.
            if elapsed < 0.5 { target.hop = -0.13 * CGFloat(sin(.pi * elapsed / 0.5)) * motion }
        case .concerned:
            // A short «no» shake when something goes wrong.
            if elapsed < 0.55 {
                target.shake = 0.055 * CGFloat(sin(elapsed * 38) * (1 - elapsed / 0.55)) * motion
            }
        case .sleepy:
            break
        }
        target.wobble *= motion
        return target
    }

    /// 1 when eyes are open, dipping to 0 during a blink.
    private func blinkFactor(at time: TimeInterval, mood: MascotMood) -> CGFloat {
        guard mood == .idle || mood == .listening || mood == .thinking else {
            blinkStart = nil
            return 1
        }
        if blinkStart == nil, time >= nextBlink { blinkStart = time }
        guard let start = blinkStart else { return 1 }
        let progress = (time - start) / Self.blinkDuration
        guard progress < 1 else {
            blinkStart = nil
            // Occasionally a quick double blink — it reads as more alive.
            nextBlink = time + (Double.random(in: 0..<1) < 0.2 ? 0.12 : .random(in: 2.4...5.5))
            return 1
        }
        return 1 - CGFloat(sin(.pi * progress))
    }
}
