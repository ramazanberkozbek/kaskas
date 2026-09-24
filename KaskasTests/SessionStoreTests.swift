import Foundation
import Testing
@testable import Kaskas

struct SessionStoreTests {
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
            snoozeDuration: 10 * 60
        )
        let startDate = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let engine = SessionEngine(configuration: configuration, now: startDate)

        store.save(configuration: configuration)
        store.save(state: engine.state)

        #expect(store.loadConfiguration() == configuration)
        #expect(store.loadSessionState() == engine.state)
    }
}
