import Foundation

@MainActor
final class SessionStore {
    private enum Key {
        static let configuration = "focusConfiguration"
        static let sessionState = "sessionState"
        static let pendingHistoryEntries = "pendingHistoryEntries"
        static let lastActiveAt = "lastActiveAt"
        static let activityJournal = "activityJournal"
        static let sessionAnnotations = "sessionAnnotations"
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

    func annotation(for interval: ActivityInterval) -> SessionAnnotation {
        loadAnnotations()[interval.sessionKey] ?? SessionAnnotation()
    }

    func annotation(for session: StudySession) -> SessionAnnotation {
        let annotations = loadAnnotations()
        var seen: Set<String> = []
        var categories: [String] = []
        var notes: [String] = []
        for interval in session.intervals where seen.insert(interval.sessionKey).inserted {
            guard let annotation = annotations[interval.sessionKey] else { continue }
            if !annotation.category.isEmpty { categories.append(annotation.category) }
            if !annotation.note.isEmpty { notes.append(annotation.note) }
        }
        return SessionAnnotation(
            category: categories.joined(separator: ", "),
            note: notes.joined(separator: "\n\n")
        )
    }

    func save(annotation: SessionAnnotation, for interval: ActivityInterval) {
        var annotations = loadAnnotations()
        if annotation.category.isEmpty && annotation.note.isEmpty {
            annotations.removeValue(forKey: interval.sessionKey)
        } else {
            annotations[interval.sessionKey] = annotation
        }
        guard let data = try? encoder.encode(annotations) else { return }
        defaults.set(data, forKey: Key.sessionAnnotations)
    }

    func save(annotation: SessionAnnotation, for session: StudySession) {
        var annotations = loadAnnotations()
        for interval in session.intervals {
            annotations.removeValue(forKey: interval.sessionKey)
        }
        if !annotation.category.isEmpty || !annotation.note.isEmpty {
            annotations[session.id] = annotation
        }
        guard let data = try? encoder.encode(annotations) else { return }
        defaults.set(data, forKey: Key.sessionAnnotations)
    }

    private func loadAnnotations() -> [String: SessionAnnotation] {
        guard let data = defaults.data(forKey: Key.sessionAnnotations) else { return [:] }
        return (try? decoder.decode([String: SessionAnnotation].self, from: data)) ?? [:]
    }

    private struct LegacySessionState: Decodable {
        let smartPauseRecords: [LegacySmartPauseRecord]?
    }
}
