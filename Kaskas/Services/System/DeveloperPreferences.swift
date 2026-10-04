import Foundation

/// Stores the toggle state for Hidden Developer Mode.
enum DeveloperPreferences {
    enum Key {
        static let isEnabled = "developerModeEnabled"
    }

    static var isEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: Key.isEnabled)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Key.isEnabled)
        }
    }

    @discardableResult
    static func toggle() -> Bool {
        let newValue = !isEnabled
        isEnabled = newValue
        return newValue
    }
}
