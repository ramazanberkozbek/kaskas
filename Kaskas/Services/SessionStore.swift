import Foundation

@MainActor
final class SessionStore {
    private enum Key {
        static let configuration = "focusConfiguration"
        static let sessionState = "sessionState"
        static let pendingHistoryEntries = "pendingHistoryEntries"
        static let lastActiveAt = "lastActiveAt"
        static let activityJournal = "activityJournal"
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

    func loadLegacySmartPauseRecords() throws -> [LegacySmartPauseRecord] {
        guard let data = defaults.data(forKey: Key.sessionState) else { return [] }
        return try decoder.decode(LegacySessionState.self, from: data).smartPauseRecords ?? []
    }

    func save(state: SessionState, observedAt: Date = Date()) {
        guard let data = try? encoder.encode(state) else {
            return
        }

        defaults.set(data, forKey: Key.sessionState)
        defaults.set(observedAt, forKey: Key.lastActiveAt)
    }

    func loadLastActiveAt() -> Date? {
        defaults.object(forKey: Key.lastActiveAt) as? Date
    }

    func loadPendingHistoryEntries() -> [BreakHistoryEntry] {
        guard let data = defaults.data(forKey: Key.pendingHistoryEntries) else { return [] }
        return (try? decoder.decode([BreakHistoryEntry].self, from: data)) ?? []
    }

    func save(pendingHistoryEntries: [BreakHistoryEntry]) {
        guard let data = try? encoder.encode(pendingHistoryEntries) else { return }
        defaults.set(data, forKey: Key.pendingHistoryEntries)
    }

    func loadActivityJournal() -> ActivityJournal {
        guard let data = defaults.data(forKey: Key.activityJournal) else { return .empty }
        return (try? decoder.decode(ActivityJournal.self, from: data)) ?? .empty
    }

    func save(activityJournal: ActivityJournal) {
        guard let data = try? encoder.encode(activityJournal) else { return }
        defaults.set(data, forKey: Key.activityJournal)
    }

    private struct LegacySessionState: Decodable {
        let smartPauseRecords: [LegacySmartPauseRecord]?
    }
}
