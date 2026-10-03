import Foundation
import Testing
@testable import Kaskas

struct SessionStoreTests {
    @Test func cachedAnnotationsImmediatelyFollowOtherWritersAndPreserveUnrelatedNotes() throws {
        let suite = "SessionStoreTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let reader = SessionStore(defaults: defaults), writer = SessionStore(defaults: defaults)
        let start = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let first = ActivityInterval(kind: .studying, startedAt: start, endedAt: start.addingTimeInterval(600))
        let second = ActivityInterval(kind: .studying, startedAt: start.addingTimeInterval(1200), endedAt: start.addingTimeInterval(1800))
        #expect(reader.annotation(for: first).isEmpty)
        writer.save(annotation: .init(note: "Alpha"), for: first)
        #expect(reader.annotation(for: first).note == "Alpha")
        // Equal length is insufficient for invalidation: compare content too.
        writer.save(annotation: .init(note: "Bravo"), for: first)
        #expect(reader.annotation(for: first).note == "Bravo")
        reader.save(annotation: .init(category: "Proje", note: "İkinci"), for: second)
        #expect(writer.annotation(for: second).note == "İkinci")
        writer.save(annotation: .init(), for: first)
        #expect(reader.annotation(for: first).isEmpty)
        #expect(reader.annotation(for: second).note == "İkinci")
        let reopened = SessionStore(defaults: defaults)
        #expect(reopened.annotation(for: first).isEmpty)
        #expect(reopened.annotation(for: second).category == "Proje")
    }

    @Test func cachedAnnotationsRecoverFromRemovedOrMalformedData() throws {
        let suite = "SessionStoreTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SessionStore(defaults: defaults)
        let start = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let interval = ActivityInterval(kind: .studying, startedAt: start, endedAt: start.addingTimeInterval(600))
        store.save(annotation: .init(note: "Not"), for: interval)
        #expect(store.annotation(for: interval).note == "Not")
        defaults.removeObject(forKey: "sessionAnnotations")
        #expect(store.annotation(for: interval).isEmpty)
        defaults.set(Data("broken JSON".utf8), forKey: "sessionAnnotations")
        #expect(store.annotation(for: interval).isEmpty)
        let restored = SessionAnnotation(category: "Eski etiket", note: "Geri geldi")
        defaults.set(try JSONEncoder().encode([interval.sessionKey: restored]), forKey: "sessionAnnotations")
        #expect(store.annotation(for: interval) == restored)
        store.save(annotation: .init(note: "Yeni not"), for: interval)
        #expect(store.annotation(for: interval).note == "Yeni not")
        #expect(SessionStore(defaults: defaults).annotation(for: interval).note == "Yeni not")
    }

    @Test
    func annotationsFollowAnIntervalAsItsEndChanges() {
        let suiteName = "SessionStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SessionStore(defaults: defaults)
        let start = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let current = ActivityInterval(kind: .studying, startedAt: start, endedAt: start.addingTimeInterval(600))
        let completed = ActivityInterval(kind: .studying, startedAt: start, endedAt: start.addingTimeInterval(1800))
        let other = ActivityInterval(kind: .studying, startedAt: start.addingTimeInterval(2000), endedAt: start.addingTimeInterval(2600))
        let annotation = SessionAnnotation(category: "Proje", note: "Taslağı bitirdim")

        store.save(annotation: annotation, for: current)

        #expect(SessionStore(defaults: defaults).annotation(for: completed) == annotation)
        #expect(store.annotation(for: other) == SessionAnnotation())

        store.save(annotation: SessionAnnotation(), for: completed)
        #expect(store.annotation(for: current) == SessionAnnotation())
    }

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
        #expect(configuration.idleDetectionEnabled == true)
        #expect(configuration.idleThreshold == 3 * 60)
        #expect(configuration.breakWarningEnabled)
        #expect(configuration.breakWarningLeadTime == 20)
        #expect(configuration.notificationPosition == .center)
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
            microReminderMascot: .glasses,
            microReminderColor: .blue,
            idleDetectionEnabled: true,
            idleThreshold: 5 * 60,
            menuBarDisplayMode: .timerOnly,
            breakWarningEnabled: false,
            breakWarningLeadTime: 25,
            notificationPosition: .right
        )
        let startDate = Date(timeIntervalSinceReferenceDate: 1_000_000)
        var engine = SessionEngine(configuration: configuration, now: startDate)
        _ = engine.send(.skipBreak, at: startDate)
        _ = engine.send(.skipBreak, at: startDate.addingTimeInterval(1))

        store.save(configuration: configuration)
        store.save(state: engine.state)

        #expect(store.loadConfiguration() == configuration)
        let savedData = defaults.data(forKey: "focusConfiguration")!
        let savedValues = try! JSONSerialization.jsonObject(with: savedData) as! [String: Any]
        #expect(savedValues["microReminderMascot"] as? String == "glasses")
        #expect(savedValues["microReminderColor"] as? String == "blue")
        #expect(savedValues["menuBarDisplayMode"] as? String == "timerOnly")
        #expect(savedValues["breakEndSoundEnabled"] as? Bool == true)
        #expect(savedValues["breakEndSound"] as? String == "Tink")
        #expect(store.loadSessionState() == engine.state)
        #expect(store.loadSessionState()?.consecutiveSkippedBreaks == 2)
    }

    @Test
    func clampsWarningLeadTimeToMaximumSixtySeconds() {
        let suiteName = "SessionStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SessionStore(defaults: defaults)
        var configuration = FocusConfiguration()
        configuration.breakWarningLeadTime = 60
        store.save(configuration: configuration)
        #expect(store.loadConfiguration().breakWarningLeadTime == 60)

        configuration.breakWarningLeadTime = 90
        store.save(configuration: configuration)
        #expect(store.loadConfiguration().breakWarningLeadTime == 60)
    }

    @Test
    func lastCheckpointCanFreezeTimeAfterAnUnexpectedExit() throws {
        let suiteName = "SessionStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SessionStore(defaults: defaults)
        let start = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let checkpoint = start.addingTimeInterval(25 * 60)
        let relaunch = checkpoint.addingTimeInterval(2 * 60)
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

    @Test
    func savesAndRestoresAppLanguage() {
        let suiteName = "SessionStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SessionStore(defaults: defaults)
        var configuration = FocusConfiguration()
        configuration.appLanguage = .english
        store.save(configuration: configuration)

        let loaded = store.loadConfiguration()
        #expect(loaded.appLanguage == .english)

        configuration.appLanguage = .turkish
        store.save(configuration: configuration)

        let reloaded = store.loadConfiguration()
        #expect(reloaded.appLanguage == .turkish)
    }
}
