import AppKit
import RadaKit
import SwiftUI

/// The menu bar glyph: a tiny Rada face. It turns pink while the microphone is on.
struct MenuBarLabel: View {
    let controller: DictationController

    var body: some View {
        Image(nsImage: MenuBarGlyph.image(for: glyphState))
            .accessibilityLabel("Rada")
    }

    private var glyphState: MenuBarGlyph.State {
        switch controller.phase {
        case .recording: .recording
        case .transcribing: .thinking
        default: .idle
        }
    }
}

enum MenuBarGlyph {
    enum State {
        case idle, recording, thinking
    }

    private static let recordingTint = NSColor(red: 0.94, green: 0.37, blue: 0.65, alpha: 1)

    static func image(for state: State) -> NSImage {
        let image = NSImage(size: CGSize(width: 18, height: 18), flipped: true) { _ in
            let body = NSBezierPath(ovalIn: CGRect(x: 1.5, y: 1.5, width: 15, height: 15))
            (state == .recording ? recordingTint : .black).setFill()
            body.fill()

            // Eyes are cut out of the sphere.
            NSGraphicsContext.current?.compositingOperation = .destinationOut
            switch state {
            case .idle, .recording:
                for x in [5.6, 10.6] {
                    NSBezierPath(roundedRect: CGRect(x: x, y: 6.2, width: 1.9, height: 4), xRadius: 0.95, yRadius: 0.95).fill()
                }
            case .thinking:
                for x in [5.4, 8.25, 11.1] {
                    NSBezierPath(ovalIn: CGRect(x: x, y: 8.1, width: 1.6, height: 1.6)).fill()
                }
            }
            return true
        }
        image.isTemplate = state != .recording
        return image
    }
}
