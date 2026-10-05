import Foundation

/// Persists session state, active configurations, and pending history entries in UserDefaults.
@MainActor
final class SessionStore {
    private enum Key {
        static let configuration = "focusConfiguration"
        static let sessionState = "sessionState"
        static let pendingHistoryEntries = "pendingHistoryEntries"
        static let lastActiveAt = "lastActiveAt"
        static let activityJournal = "activityJournal"
        static let appUsageJournal = "appUsageJournal"
        static let excludedUsageJournal = "excludedUsageJournal"
        static let automaticCategories = "automaticCategoryDetectionEnabled"
        static let sessionAnnotations = "sessionAnnotations"
    }

    let appExclusions: AppExclusionPreferences
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var annotationCache: (data: Data?, values: [String: SessionAnnotation])?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appExclusions = AppExclusionPreferences(defaults: defaults)
    }

    var automaticCategoryDetectionEnabled: Bool {
        get { defaults.object(forKey: Key.automaticCategories) == nil ? true : defaults.bool(forKey: Key.automaticCategories) }
        set { defaults.set(newValue, forKey: Key.automaticCategories) }
    }

    func loadExcludedUsageJournal() -> ExcludedUsageJournal {
        guard let data = defaults.data(forKey: Key.excludedUsageJournal) else { return .init() }
        return (try? decoder.decode(ExcludedUsageJournal.self, from: data)) ?? .init()
    }

    func save(excludedUsageJournal: ExcludedUsageJournal) {
        guard let data = try? encoder.encode(excludedUsageJournal) else { return }
        defaults.set(data, forKey: Key.excludedUsageJournal)
    }

    func loadAppUsageJournal() -> AppUsageJournal {
        guard let data = defaults.data(forKey: Key.appUsageJournal) else { return AppUsageJournal() }
        return (try? decoder.decode(AppUsageJournal.self, from: data)) ?? AppUsageJournal()
    }

    func save(appUsageJournal: AppUsageJournal) {
        guard let data = try? encoder.encode(appUsageJournal) else { return }
        defaults.set(data, forKey: Key.appUsageJournal)
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
        var categoryAnnotations: [SessionAnnotation] = []
        var notes: [String] = []
        for interval in session.intervals where seen.insert(interval.sessionKey).inserted {
            guard let annotation = annotations[interval.sessionKey] else { continue }
            if !annotation.category.isEmpty { categories.append(annotation.category) }
            else if let id = annotation.categoryID { categories.append(id) }
            if annotation.hasManualCategory { categoryAnnotations.append(annotation) }
            if !annotation.note.isEmpty { notes.append(annotation.note) }
        }
        let ids = Set(categoryAnnotations.compactMap(\.categoryID))
        let sharedID = ids.count == 1 && categoryAnnotations.allSatisfy { $0.categoryID != nil }
            ? ids.first : nil
        return SessionAnnotation(
            category: categories.joined(separator: ", "),
            note: notes.joined(separator: "\n\n"),
            categoryID: sharedID
        )
    }

    func save(annotation: SessionAnnotation, for interval: ActivityInterval) {
        var annotations = loadAnnotations()
        if annotation.isEmpty {
            annotations.removeValue(forKey: interval.sessionKey)
        } else {
            annotations[interval.sessionKey] = annotation
        }
        saveAnnotations(annotations)
    }

    func save(annotation: SessionAnnotation, for session: StudySession) {
        var annotations = loadAnnotations()
        for interval in session.intervals {
            annotations.removeValue(forKey: interval.sessionKey)
        }
        if !annotation.isEmpty {
            annotations[session.id] = annotation
        }
        saveAnnotations(annotations)
    }

    func clearAnnotations() {
        defaults.removeObject(forKey: Key.sessionAnnotations)
        annotationCache = nil
    }

    private func loadAnnotations() -> [String: SessionAnnotation] {
        let data = defaults.data(forKey: Key.sessionAnnotations)
        // Check the stored bytes so writes by another store instance and resets
        // are visible immediately, without decoding unchanged JSON on each read.
        if let annotationCache, annotationCache.data == data { return annotationCache.values }
        let values = data.flatMap { try? decoder.decode([String: SessionAnnotation].self, from: $0) } ?? [:]
        annotationCache = (data, values)
        return values
    }

    private func saveAnnotations(_ values: [String: SessionAnnotation]) {
        guard let data = try? encoder.encode(values) else { return }
        defaults.set(data, forKey: Key.sessionAnnotations)
        annotationCache = (data, values)
    }

    /// Editing notes does not turn an automatic label into a manual override.
    /// Returning to automatic preserves each interval's notes unless the note itself was edited.
    func save(categorySelection: SessionCategorySelection, categoryName: String?, note: String, for session: StudySession) {
        let original = annotation(for: session)
        let categoryChanged = categorySelection != SessionCategorySelection(annotation: original)
        let noteChanged = note != original.note
        guard categoryChanged || noteChanged else { return }
        var annotations = loadAnnotations()
        for key in Set(session.intervals.map(\.sessionKey)) {
            var value = annotations[key] ?? SessionAnnotation()
            if categoryChanged { value.category = ""; value.categoryID = nil }
            if noteChanged { value.note = "" }
            if value.isEmpty { annotations.removeValue(forKey: key) }
            else { annotations[key] = value }
        }
        var first = annotations[session.id] ?? SessionAnnotation()
        if categoryChanged {
            switch categorySelection {
            case .automatic: break
            case .category(let id):
                first.categoryID = id
                first.category = categoryName ?? ""
            case .legacy(let label): first.category = label
            }
        }
        if noteChanged { first.note = note }
        if first.isEmpty { annotations.removeValue(forKey: session.id) }
        else { annotations[session.id] = first }
        saveAnnotations(annotations)
    }
}
