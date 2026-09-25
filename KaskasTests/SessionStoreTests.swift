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
            microReminderColor: .blue
        )
        let startDate = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let engine = SessionEngine(configuration: configuration, now: startDate)

        store.save(configuration: configuration)
        store.save(state: engine.state)

        #expect(store.loadConfiguration() == configuration)
        let savedData = defaults.data(forKey: "focusConfiguration")!
        let savedValues = try! JSONSerialization.jsonObject(with: savedData) as! [String: Any]
        #expect(savedValues["microReminderMascot"] as? String == "flame")
        #expect(savedValues["microReminderColor"] as? String == "blue")
        #expect(store.loadSessionState() == engine.state)
    }
}
