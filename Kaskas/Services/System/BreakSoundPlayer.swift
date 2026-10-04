import AppKit

/// Plays audio alerts for breaks and settings previews.
@MainActor
enum BreakSoundPlayer {
    private static var previewSound: NSSound?

    static var isTestEnvironment: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
        ProcessInfo.processInfo.environment["XCInjectBundleInto"] != nil ||
        ProcessInfo.processInfo.environment["XCTestBundlePath"] != nil ||
        NSClassFromString("XCTestCase") != nil
    }

    static func play(_ sound: BreakSound) {
        guard !isTestEnvironment else { return }
        NSSound(named: NSSound.Name(sound.rawValue))?.play()
    }

    static func preview(_ sound: BreakSound) {
        guard !isTestEnvironment else { return }
        previewSound?.stop()
        previewSound = NSSound(named: NSSound.Name(sound.rawValue))
        previewSound?.play()
    }
}
