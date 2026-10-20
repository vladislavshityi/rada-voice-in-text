import SwiftUI

/// The living Rada mascot. Redraws every frame while visible.
struct MascotView: View {
    var mood: MascotMood
    var level: Float = 0
    var glow = true

    @StateObject private var animator = MascotAnimator()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60)) { timeline in
            Canvas { context, size in
                let frame = animator.frame(
                    at: timeline.date.timeIntervalSinceReferenceDate,
                    mood: mood, level: CGFloat(level), reduceMotion: reduceMotion
                )
                MascotRenderer.draw(frame, in: &context, size: size, glow: glow)
            }
        }
        .accessibilityLabel("Rada")
    }
}

/// A still portrait of the mascot for icons.
struct MascotPortrait: View {
    var glow = true

    var body: some View {
        Canvas { context, size in
            MascotRenderer.draw(MascotFrame(pose: .portrait, swirlPhase: 0.6, time: 0), in: &context, size: size, glow: glow)
        }
    }
}
