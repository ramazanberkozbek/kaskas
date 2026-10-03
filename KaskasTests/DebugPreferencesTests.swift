#if DEBUG
import Foundation
import Testing
@testable import Kaskas

struct DebugPreferencesTests {
    @Test
    func migrationPreservesSwitchesAndExistingDestinationValues() throws {
        let legacyName = "kaskas.tests.legacy.\(UUID().uuidString)"
        let debugName = "kaskas.tests.debug.\(UUID().uuidString)"
        let legacy = try #require(UserDefaults(suiteName: legacyName))
        let store = try #require(UserDefaults(suiteName: debugName))
        defer {
            legacy.removePersistentDomain(forName: legacyName)
            store.removePersistentDomain(forName: debugName)
        }
        legacy.set(true, forKey: DebugPreferences.Key.modeEnabled)
        legacy.set(true, forKey: DebugPreferences.Key.sessionDetailsEnabled)
        legacy.set("keep", forKey: "regularPreference")
        store.set(false, forKey: DebugPreferences.Key.sessionDetailsEnabled)

        DebugPreferences.migrateLegacyPreferences(from: legacy, to: store)
        DebugPreferences.migrateLegacyPreferences(from: legacy, to: store)

        #expect(store.bool(forKey: DebugPreferences.Key.modeEnabled))
        #expect(!store.bool(forKey: DebugPreferences.Key.sessionDetailsEnabled))
        #expect(legacy.object(forKey: DebugPreferences.Key.modeEnabled) == nil)
        #expect(legacy.object(forKey: DebugPreferences.Key.sessionDetailsEnabled) == nil)
        #expect(legacy.string(forKey: "regularPreference") == "keep")
        #expect(store.object(forKey: "regularPreference") == nil)
    }
}
#endif
