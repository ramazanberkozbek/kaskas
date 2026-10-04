import Foundation

/// Tracks continuous focus and break intervals, buffering changes in memory before saving.
@MainActor
final class ActivityTracker {
    private let sessionStore: SessionStore
    private let activityStore: (any ActivityRecording)?
    private(set) var journal: ActivityJournal
    private(set) var completedIntervalsRevision = 0
    private var persistenceTask: Task<Void, Never>?
    private var persistenceRequested = false
    private(set) var storageFailed = false {
        didSet { if storageFailed != oldValue { onStorageFailureChanged?(storageFailed) } }
    }
    var onStorageFailureChanged: ((Bool) -> Void)?

    init(sessionStore: SessionStore, activityStore: (any ActivityRecording)?) {
        self.sessionStore = sessionStore
        self.activityStore = activityStore
        journal = sessionStore.loadActivityJournal()
        storageFailed = activityStore == nil
    }

    func resume(as kind: ActivityKind, at now: Date) {
        if let previous = journal.cursor {
            if previous.kind == .studying || previous.kind == .breakTime || previous.kind == .meeting {
                append(previous.kind, from: previous.startedAt, to: previous.checkpointAt)
                append(.kaskasPaused, from: previous.checkpointAt, to: now)
            } else {
                append(previous.kind, from: previous.startedAt, to: now)
            }
        }
        journal.cursor = ActivityCursor(kind: kind, startedAt: now, checkpointAt: now)
        checkpointAndEnqueue()
    }

    func update(to kind: ActivityKind, at now: Date) {
        guard let cursor = journal.cursor else {
            journal.cursor = ActivityCursor(kind: kind, startedAt: now, checkpointAt: now)
            checkpointAndEnqueue()
            return
        }
        if cursor.kind == kind {
            journal.cursor = ActivityCursor(
                kind: kind,
                startedAt: cursor.startedAt,
                checkpointAt: max(cursor.checkpointAt, now)
            )
        } else {
            append(cursor.kind, from: cursor.startedAt, to: now)
            journal.cursor = ActivityCursor(kind: kind, startedAt: now, checkpointAt: now)
        }
        checkpointAndEnqueue()
    }

    func intervals(from start: Date, to end: Date, now: Date = Date()) -> [ActivityInterval] {
        var byID: [String: ActivityInterval] = [:]
        if let activityStore {
            do {
                for interval in try activityStore.intervals(from: start, to: end) {
                    byID[interval.id] = interval
                }
            } catch {
                storageFailed = true
                NSLog("Kaskas: Failed to read activity history: %@", String(describing: error))
            }
        }
        for interval in journal.pending {
            byID[interval.id] = interval
        }
        if let cursor = journal.cursor {
            let interval = ActivityInterval(
                kind: cursor.kind,
                startedAt: cursor.startedAt,
                endedAt: cursor.kind == .studying || cursor.kind == .breakTime
                    ? max(cursor.checkpointAt, now)
                    : now
            )
            byID[interval.id] = interval
        }
        return byID.values.filter { $0.startedAt < end && $0.endedAt > start }
            .sorted { $0.startedAt < $1.startedAt }
    }


    func intervalsAsync(from start: Date, to end: Date, now: Date, includeActiveCursor: Bool = true) async -> [ActivityInterval] {
        var live = journal.pending
        if includeActiveCursor, let cursor = journal.cursor { live.append(ActivityInterval(kind: cursor.kind, startedAt: cursor.startedAt,
                endedAt: cursor.kind == .studying || cursor.kind == .breakTime ? max(cursor.checkpointAt, now) : now)) }
        var persisted: [ActivityInterval] = []
        do {
            if let activityStore { persisted = try await activityStore.intervalsAsync(from: start, to: end) }
        } catch is CancellationError {
            return []
        } catch {
            storageFailed = true
            NSLog("Kaskas: Failed to read history: %@", String(describing: error))
        }
        guard !Task.isCancelled else { return [] }
        return await Self.merge(persisted: persisted, live: live, from: start, to: end)
    }

    @concurrent private static func merge(persisted: [ActivityInterval], live: [ActivityInterval], from start: Date, to end: Date) async -> [ActivityInterval] {
        var byID: [String: ActivityInterval] = [:]
        for value in persisted { byID[value.id] = value }
        for value in live { byID[value.id] = value }
        return byID.values.filter { $0.startedAt < end && $0.endedAt > start }
            .sorted { $0.startedAt < $1.startedAt }
    }

    private func append(_ kind: ActivityKind, from start: Date, to end: Date) {
        guard end > start else { return }
        journal.pending.append(ActivityInterval(kind: kind, startedAt: start, endedAt: end))
        completedIntervalsRevision += 1
    }

    private func checkpointAndEnqueue() {
        sessionStore.save(activityJournal: journal)
        schedulePersistence()
    }

    /// Writes belong to tracking events, never to a history read. One task drains
    /// ordered batches; it retains the tracker until every acknowledgement is saved.
    private func schedulePersistence() {
        guard activityStore != nil, !journal.pending.isEmpty else { return }
        persistenceRequested = true
        guard persistenceTask == nil else { return }
        persistenceTask = Task {
            while persistenceRequested {
                persistenceRequested = false
                guard let activityStore, !journal.pending.isEmpty else { continue }
                let batch = journal.pending
                do {
                    try await activityStore.insertBatch(batch)
                    let committed = Set(batch.map(\.id))
                    journal.pending.removeAll { committed.contains($0.id) }
                    sessionStore.save(activityJournal: journal)
                    storageFailed = false
                } catch {
                    storageFailed = true
                    NSLog("Kaskas: Failed to save history: %@", String(describing: error))
                    // Keep the durable outbox. A later tracking checkpoint retries;
                    // reads do not write, and failures do not spin in a retry loop.
                }
            }
            persistenceTask = nil
        }
    }

    /// Await outstanding writes for lifecycle tests and explicit shutdown work.
    func waitForPersistence() async {
        await persistenceTask?.value
    }
}
