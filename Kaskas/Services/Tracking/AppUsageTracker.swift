import Foundation

/// Tracks active application usage segments and resolves their categories.
@MainActor
final class AppUsageTracker {
    private let sessionStore: SessionStore
    private let usageStore: (any AppUsageRecording)?
    private(set) var journal: AppUsageJournal
    private var persistenceTask: Task<Void, Never>?
    private var persistenceRequested = false
    private var persistenceSuspended = false
    private(set) var storageFailed: Bool {
        didSet { if storageFailed != oldValue { onStorageFailureChanged?(storageFailed) } }
    }
    var onStorageFailureChanged: ((Bool) -> Void)?

    init(sessionStore: SessionStore, usageStore: (any AppUsageRecording)?) {
        self.sessionStore = sessionStore
        self.usageStore = usageStore
        storageFailed = usageStore == nil
        journal = sessionStore.loadAppUsageJournal()
        // The time between the last verified checkpoint and launch has no known app.
        if let cursor = journal.cursor {
            append(cursor, endingAt: cursor.checkpointAt)
            journal.cursor = nil
        }
        checkpointAndEnqueue()
    }

    func update(app: ForegroundApp?, resolution: CategoryResolution = .unmatched, at now: Date) {
        if let cursor = journal.cursor {
            if let app, cursor.app == app, cursor.resolution == resolution {
                journal.cursor?.checkpointAt = max(cursor.checkpointAt, now)
                checkpointAndEnqueue()
                return
            }
            append(cursor, endingAt: now)
        }
        journal.cursor = app.map {
            AppUsageCursor(id: UUID(), app: $0, resolution: resolution, startedAt: now, checkpointAt: now)
        }
        checkpointAndEnqueue()
    }

    func clockDidChange() {
        if let cursor = journal.cursor { append(cursor, endingAt: cursor.checkpointAt) }
        journal.cursor = nil
        checkpointAndEnqueue()
    }

    func segments(from start: Date, to end: Date, now: Date) -> [AppUsageSegment] {
        var byID: [UUID: AppUsageSegment] = [:]
        if let usageStore {
            do {
                for segment in try usageStore.segments(from: start, to: end) { byID[segment.id] = segment }
            } catch {
                storageFailed = true
                NSLog("Kaskas: Failed to read category history: %@", String(describing: error))
            }
        }
        for segment in journal.pending { byID[segment.id] = segment }
        if let cursor = journal.cursor { byID[cursor.id] = cursor.segment(endingAt: now) }
        return byID.values.filter { $0.startedAt < end && $0.endedAt > start }
            .sorted { $0.startedAt < $1.startedAt }
    }


    func segmentsAsync(from start: Date, to end: Date, now: Date) async -> [AppUsageSegment] {
        var live = journal.pending
        if let cursor = journal.cursor { live.append(cursor.segment(endingAt: now)) }
        var persisted: [AppUsageSegment] = []
        do {
            if let usageStore { persisted = try await usageStore.segmentsAsync(from: start, to: end) }
        } catch is CancellationError {
            return []
        } catch {
            storageFailed = true
            NSLog("Kaskas: Failed to read history: %@", String(describing: error))
        }
        guard !Task.isCancelled else { return [] }
        return await Self.merge(persisted: persisted, live: live, from: start, to: end)
    }

    @concurrent private static func merge(persisted: [AppUsageSegment], live: [AppUsageSegment], from start: Date, to end: Date) async -> [AppUsageSegment] {
        var byID: [UUID: AppUsageSegment] = [:]
        for value in persisted { byID[value.id] = value }
        for value in live { byID[value.id] = value }
        return byID.values.filter { $0.startedAt < end && $0.endedAt > start }
            .sorted { $0.startedAt < $1.startedAt }
    }

    private func append(_ cursor: AppUsageCursor, endingAt end: Date) {
        guard end > cursor.startedAt else { return }
        journal.pending.append(cursor.segment(endingAt: end))
    }

    private func checkpointAndEnqueue() {
        sessionStore.save(appUsageJournal: journal)
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
                    sessionStore.save(appUsageJournal: journal)
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

    func suspendPersistence() { persistenceSuspended = true }

    func resumePersistence() {
        persistenceSuspended = false
        schedulePersistence()
    }

    /// Called only after the database deletion succeeds and outstanding writes finish.
    func resetHistory(at now: Date) {
        journal.pending.removeAll()
        if let cursor = journal.cursor {
            journal.cursor = AppUsageCursor(id: UUID(), app: cursor.app, resolution: cursor.resolution,
                startedAt: now, checkpointAt: now)
        }
        sessionStore.save(appUsageJournal: journal)
    }

    /// Await outstanding writes for lifecycle tests and explicit shutdown work.
    func waitForPersistence() async {
        await persistenceTask?.value
    }
}
