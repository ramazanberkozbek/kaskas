import Foundation

/// Tracks active application usage segments and resolves their categories.
@MainActor
final class AppUsageTracker {
    private let sessionStore: SessionStore
    private let usageStore: (any AppUsageRecording)?
    private(set) var journal: AppUsageJournal
    private(set) var storageFailed: Bool

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
        saveAndFlush()
    }

    func update(app: ForegroundApp?, resolution: CategoryResolution = .unmatched, at now: Date) {
        if let cursor = journal.cursor {
            if let app, cursor.app == app, cursor.resolution == resolution {
                journal.cursor?.checkpointAt = max(cursor.checkpointAt, now)
                saveAndFlush()
                return
            }
            append(cursor, endingAt: now)
        }
        journal.cursor = app.map {
            AppUsageCursor(id: UUID(), app: $0, resolution: resolution, startedAt: now, checkpointAt: now)
        }
        saveAndFlush()
    }

    func clockDidChange() {
        if let cursor = journal.cursor { append(cursor, endingAt: cursor.checkpointAt) }
        journal.cursor = nil
        saveAndFlush()
    }

    func segments(from start: Date, to end: Date, now: Date) -> [AppUsageSegment] {
        flush()
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

    private func saveAndFlush() {
        sessionStore.save(appUsageJournal: journal)
        flush()
    }

    private func flush() {
        guard let usageStore, !journal.pending.isEmpty else { return }
        do {
            for segment in journal.pending { try usageStore.insert(segment) }
            journal.pending.removeAll()
            sessionStore.save(appUsageJournal: journal)
            storageFailed = false
        } catch {
            storageFailed = true
            NSLog("Kaskas: Failed to save category history: %@", String(describing: error))
        }
    }
}
