import Foundation

@MainActor
final class SessionStore {
    private enum Key {
        static let configuration = "focusConfiguration"
        static let sessionState = "sessionState"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadConfiguration() -> FocusConfiguration {
        guard
            let data = defaults.data(forKey: Key.configuration),
            let configuration = try? decoder.decode(FocusConfiguration.self, from: data)
        else {
            return FocusConfiguration()
        }

        return configuration
    }

    func save(configuration: FocusConfiguration) {
        guard let data = try? encoder.encode(configuration) else {
            return
        }

        defaults.set(data, forKey: Key.configuration)
    }

    func loadSessionState() -> SessionState? {
        guard let data = defaults.data(forKey: Key.sessionState) else {
            return nil
        }

        return try? decoder.decode(SessionState.self, from: data)
    }

    func save(state: SessionState) {
        guard let data = try? encoder.encode(state) else {
            return
        }

        defaults.set(data, forKey: Key.sessionState)
    }
}
