import AppKit

/// Short system sounds marking the start and end of recording.
@MainActor
enum SoundEffects {
    static func recordingStarted() { play("Tink") }
    static func recordingStopped() { play("Pop") }

    private static func play(_ name: String) {
        guard let sound = NSSound(named: NSSound.Name(name)) else { return }
        sound.volume = 0.35
        sound.play()
    }
}
