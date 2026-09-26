import Foundation
import Testing
@testable import Kaskas

struct SessionStoreTests {
    @Test
    func restoresConfigurationSavedWithRemovedAppearanceOptions() {
        let suiteName = "SessionStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let legacyConfiguration = """
        {
          "focusDuration": 3600,
          "microReminderInterval": 900,
          "breakDuration": 600,
          "snoozeDuration": 300,
          "breakBackground": "aurora",
          "breakBackgroundStyle": "frost",
          "breakOverlayDim": 0.4,
          "microReminderMascot": "wizard"
        }
        """
        defaults.set(Data(legacyConfiguration.utf8), forKey: "focusConfiguration")

        let configuration = SessionStore(defaults: defaults).loadConfiguration()
        #expect(configuration.focusDuration == 3600)
        #expect(configuration.breakBackground == .aurora)
        #expect(configuration.breakLayout == .horizon)
        #expect(configuration.breakSoundEnabled == false)
        #expect(configuration.breakSound == .glass)
        #expect(configuration.microReminderMascot == .flame)
        #expect(configuration.microReminderColor == .peach)
        #expect(configuration.smartPauseEnabled == true)
        #expect(configuration.smartPauseIdleDuration == 3 * 60)
        #expect(configuration.pauseDuringCalls == false)
        #expect(configuration.pauseDuringVideo == false)
        #expect(configuration.pauseForFocusApps == false)
        #expect(configuration.notifyDuringCalls == false)
        #expect(configuration.smartPauseResumeDelay == 0)
    }

    @Test
    func savesAndRestoresConfigurationAndSessionState() {
        let suiteName = "SessionStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SessionStore(defaults: defaults)
        let configuration = FocusConfiguration(
            focusDuration: 60 * 60,
            microReminderInterval: 15 * 60,
            breakDuration: 10 * 60,
            snoozeDuration: 10 * 60,
            breakLayout: .gentleBar,
            breakSoundEnabled: true,
            breakSound: .ping,
            microReminderMascot: .flame,
            microReminderColor: .blue,
            smartPauseEnabled: true,
            smartPauseIdleDuration: 5 * 60,
            pauseDuringCalls: true,
            notifyDuringCalls: true,
            microphoneUID: "test-microphone",
            pauseDuringVideo: true,
            notifyDuringVideo: false,
            pauseForFocusApps: true,
            notifyForFocusApps: true,
            focusAppBundleIDs: ["com.apple.dt.Xcode"],
            smartPauseResumeDelay: 120
        )
        let startDate = Date(timeIntervalSinceReferenceDate: 1_000_000)
        var engine = SessionEngine(configuration: configuration, now: startDate)
        _ = engine.skipBreak(at: startDate)
        _ = engine.skipBreak(at: startDate.addingTimeInterval(1))

        store.save(configuration: configuration)
        store.save(state: engine.state)

        #expect(store.loadConfiguration() == configuration)
        let savedData = defaults.data(forKey: "focusConfiguration")!
        let savedValues = try! JSONSerialization.jsonObject(with: savedData) as! [String: Any]
        #expect(savedValues["microReminderMascot"] as? String == "flame")
        #expect(savedValues["microReminderColor"] as? String == "blue")
        #expect(store.loadSessionState() == engine.state)
        #expect(store.loadSessionState()?.consecutiveSkippedBreaks == 2)
    }
}
