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
        #expect(configuration.breakEndSoundEnabled == false)
        #expect(configuration.breakEndSound == .glass)
        #expect(configuration.longBreakEnabled == false)
        #expect(configuration.longBreakFrequency == 3)
        #expect(configuration.longBreakDuration == 10 * 60)
        #expect(configuration.microReminderMascot == .flame)
        #expect(configuration.microReminderColor == .peach)
        #expect(configuration.menuBarDisplayMode == .iconAndTimer)
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
            longBreakEnabled: true,
            longBreakFrequency: 4,
            longBreakDuration: 20 * 60,
            snoozeDuration: 10 * 60,
            breakLayout: .gentleBar,
            breakSoundEnabled: true,
            breakSound: .ping,
            breakEndSoundEnabled: true,
            breakEndSound: .tink,
            microReminderMascot: .flame,
            microReminderColor: .blue,
            menuBarDisplayMode: .timerOnly
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
        #expect(savedValues["menuBarDisplayMode"] as? String == "timerOnly")
        #expect(savedValues["breakEndSoundEnabled"] as? Bool == true)
        #expect(savedValues["breakEndSound"] as? String == "Tink")
        #expect(store.loadSessionState() == engine.state)
        #expect(store.loadSessionState()?.consecutiveSkippedBreaks == 2)
    }

    @Test
    func lastCheckpointCanFreezeTimeAfterAnUnexpectedExit() throws {
        let suiteName = "SessionStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SessionStore(defaults: defaults)
        let start = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let checkpoint = start.addingTimeInterval(25 * 60)
        let relaunch = checkpoint.addingTimeInterval(3 * 60 * 60)
        let original = SessionEngine(now: start)
        store.save(state: original.state, observedAt: checkpoint)

        var restored = SessionEngine(
            configuration: original.configuration,
            restoredState: try #require(store.loadSessionState())
        )
        restored.beginSystemPause(at: try #require(store.loadLastActiveAt()))
        restored.endSystemPause(at: relaunch, meetingActive: false)

        #expect(restored.snapshot(at: relaunch).remaining == 20 * 60)
        #expect(restored.process(at: relaunch).isEmpty)
    }

    @Test
    func ignoresRemovedSmartPauseDataInSavedSession() throws {
        let suiteName = "SessionStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SessionStore(defaults: defaults)
        let startDate = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let engine = SessionEngine(now: startDate)
        store.save(configuration: engine.configuration)
        store.save(state: engine.state)

        var savedConfiguration = try #require(
            JSONSerialization.jsonObject(with: defaults.data(forKey: "focusConfiguration")!) as? [String: Any]
        )
        savedConfiguration["smartPauseEnabled"] = true
        savedConfiguration["pauseDuringCalls"] = true
        defaults.set(try JSONSerialization.data(withJSONObject: savedConfiguration), forKey: "focusConfiguration")

        var savedState = try #require(
            JSONSerialization.jsonObject(with: defaults.data(forKey: "sessionState")!) as? [String: Any]
        )
        savedState["pendingIdleStartedAt"] = startDate.timeIntervalSinceReferenceDate
        savedState["triggerPauseStartedAt"] = startDate.timeIntervalSinceReferenceDate
        defaults.set(try JSONSerialization.data(withJSONObject: savedState), forKey: "sessionState")

        #expect(store.loadConfiguration() == engine.configuration)
        let restored = try #require(store.loadSessionState())
        var resumed = SessionEngine(configuration: engine.configuration, restoredState: restored)
        #expect(resumed.process(at: startDate.addingTimeInterval(45 * 60)) == [.fullBreakDue])

        store.save(configuration: resumed.configuration)
        store.save(state: resumed.state)
        let cleanConfiguration = try #require(
            JSONSerialization.jsonObject(with: defaults.data(forKey: "focusConfiguration")!) as? [String: Any]
        )
        let cleanState = try #require(
            JSONSerialization.jsonObject(with: defaults.data(forKey: "sessionState")!) as? [String: Any]
        )
        #expect(cleanConfiguration["smartPauseEnabled"] == nil)
        #expect(cleanState["pendingIdleStartedAt"] == nil)
        #expect(cleanState["triggerPauseStartedAt"] == nil)
    }
}
