#if DEBUG
import Foundation

/// Shared storage for development controls; never used by Release builds.
enum DebugPreferences {
    enum Key {
        static let modeEnabled = "debugModeEnabled"
        static let sessionDetailsEnabled = "debugSessionDetailsEnabled"
    }

    static let store: UserDefaults = {
        guard let store = UserDefaults(suiteName: "com.ramazanozbek.kaskas.debug") else {
            preconditionFailure("Unable to create debug preferences storage")
        }
        migrateLegacyPreferences(from: .standard, to: store)
        return store
    }()

    /// Preserve existing switches on first use, then remove legacy production keys.
    static func migrateLegacyPreferences(from legacy: UserDefaults, to store: UserDefaults) {
        for key in [Key.modeEnabled, Key.sessionDetailsEnabled] {
            if let value = legacy.object(forKey: key) {
                if store.object(forKey: key) == nil {
                    store.set(value, forKey: key)
                }
                legacy.removeObject(forKey: key)
            }
        }
    }
}
#endif
