import Foundation

/// Records anonymous excluded intervals, including crash recovery and durable writes.
@MainActor
final class ExcludedUsageTracker {
    private let sessionStore: SessionStore
    private let usageStore: (any ExcludedUsageRecording)?
    private(set) var journal: ExcludedUsageJournal
    private var persistenceTask: Task<Void, Never>?
    private var persistenceRequested = false
    private var persistenceSuspended = false
    private(set) var storageFailed: Bool {
        didSet { if storageFailed != oldValue { onStorageFailureChanged?(storageFailed) } }
    }
    var onStorageFailureChanged: ((Bool) -> Void)?

    init(sessionStore: SessionStore, usageStore: (any ExcludedUsageRecording)?) {
        self.sessionStore = sessionStore
        self.usageStore = usageStore
        storageFailed = usageStore == nil
        journal = sessionStore.loadExcludedUsageJournal()
        // The time between the last verified checkpoint and launch has no known app.
        if let cursor = journal.cursor {
            append(cursor, endingAt: cursor.checkpointAt)
            journal.cursor = nil
        }
        checkpointAndEnqueue()
    }

    func update(isExcluded: Bool, at now: Date) {
        guard isExcluded || journal.cursor != nil || !journal.pending.isEmpty else { return }
        if let cursor = journal.cursor {
            if isExcluded {
                journal.cursor?.checkpointAt = max(cursor.checkpointAt, now)
                checkpointAndEnqueue()
                return
            }
            append(cursor, endingAt: now)
        }
        journal.cursor = isExcluded
            ? ExcludedUsageCursor(id: UUID(), startedAt: now, checkpointAt: now) : nil
        checkpointAndEnqueue()
    }

    func clockDidChange() {
        if let cursor = journal.cursor { append(cursor, endingAt: cursor.checkpointAt) }
        journal.cursor = nil
        checkpointAndEnqueue()
    }

    func intervals(from start: Date, to end: Date, now: Date) -> [ExcludedUsageInterval] {
        var byID: [UUID: ExcludedUsageInterval] = [:]
        if let usageStore {
            do {
                for segment in try usageStore.intervals(from: start, to: end) { byID[segment.id] = segment }
            } catch {
                storageFailed = true
                NSLog("Kaskas: Failed to read excluded history: %@", String(describing: error))
            }
        }
        for segment in journal.pending { byID[segment.id] = segment }
        if let cursor = journal.cursor { byID[cursor.id] = cursor.interval(endingAt: now) }
        return byID.values.filter { $0.startedAt < end && $0.endedAt > start }
            .sorted { $0.startedAt < $1.startedAt }
    }


    func intervalsAsync(from start: Date, to end: Date, now: Date) async -> [ExcludedUsageInterval] {
        var live = journal.pending
        if let cursor = journal.cursor { live.append(cursor.interval(endingAt: now)) }
        var persisted: [ExcludedUsageInterval] = []
        do {
            if let usageStore { persisted = try await usageStore.intervalsAsync(from: start, to: end) }
        } catch is CancellationError {
            return []
        } catch {
            storageFailed = true
            NSLog("Kaskas: Failed to read excluded history: %@", String(describing: error))
        }
        guard !Task.isCancelled else { return [] }
        return await Self.merge(persisted: persisted, live: live, from: start, to: end)
    }

    @concurrent private static func merge(persisted: [ExcludedUsageInterval], live: [ExcludedUsageInterval], from start: Date, to end: Date) async -> [ExcludedUsageInterval] {
        var byID: [UUID: ExcludedUsageInterval] = [:]
        for value in persisted { byID[value.id] = value }
        for value in live { byID[value.id] = value }
        return byID.values.filter { $0.startedAt < end && $0.endedAt > start }
            .sorted { $0.startedAt < $1.startedAt }
    }

    private func append(_ cursor: ExcludedUsageCursor, endingAt end: Date) {
        guard end > cursor.startedAt else { return }
        journal.pending.append(cursor.interval(endingAt: end))
    }

    private func checkpointAndEnqueue() {
        sessionStore.save(excludedUsageJournal: journal)
        schedulePersistence()
    }

    /// Writes belong to tracking events, never to a history read. One task drains
    /// ordered batches; it retains the tracker until every acknowledgement is saved.
    private func schedulePersistence() {
        guard !persistenceSuspended, usageStore != nil, !journal.pending.isEmpty else { return }
        persistenceRequested = true
        guard persistenceTask == nil else { return }
        persistenceTask = Task {
            while persistenceRequested && !persistenceSuspended {
                persistenceRequested = false
                guard let usageStore, !journal.pending.isEmpty else { continue }
                let batch = journal.pending
                do {
                    try await usageStore.insertBatch(batch)
                    let committed = Set(batch.map(\.id))
                    journal.pending.removeAll { committed.contains($0.id) }
                    sessionStore.save(excludedUsageJournal: journal)
                    storageFailed = false
                } catch {
                    storageFailed = true
                    NSLog("Kaskas: Failed to save excluded history: %@", String(describing: error))
                    // Keep the durable outbox. A later tracking checkpoint retries;
                    // reads do not write, and failures do not spin in a retry loop.
                }
            }
            persistenceTask = nil
        }
    }

    func suspendPersistence() { persistenceSuspended = true }

    func resumePersistence() {
        persistenceSuspended = false
        schedulePersistence()
    }

    /// Called only after the database deletion succeeds and outstanding writes finish.
    func resetHistory(at now: Date) {
        journal.pending.removeAll()
        if journal.cursor != nil {
            journal.cursor = ExcludedUsageCursor(id: UUID(), startedAt: now, checkpointAt: now)
        }
        sessionStore.save(excludedUsageJournal: journal)
    }

    /// Await outstanding writes for lifecycle tests and explicit shutdown work.
    func waitForPersistence() async {
        await persistenceTask?.value
    }
}
