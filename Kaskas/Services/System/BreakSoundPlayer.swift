import AppKit

/// Plays audio alerts for breaks and settings previews.
@MainActor
enum BreakSoundPlayer {
    private static var previewSound: NSSound?

    static func play(_ sound: BreakSound) {
        NSSound(named: NSSound.Name(sound.rawValue))?.play()
    }

    static func preview(_ sound: BreakSound) {
        previewSound?.stop()
        previewSound = NSSound(named: NSSound.Name(sound.rawValue))
        previewSound?.play()
    }
}
