import Foundation

@MainActor
final class ActivityTracker {
    private let sessionStore: SessionStore
    private let activityStore: (any ActivityRecording)?
    private(set) var journal: ActivityJournal
    private(set) var storageFailed = false

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
        saveAndFlush()
    }

    func update(to kind: ActivityKind, at now: Date) {
        guard let cursor = journal.cursor else {
            journal.cursor = ActivityCursor(kind: kind, startedAt: now, checkpointAt: now)
            saveAndFlush()
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
        saveAndFlush()
    }

    func intervals(from start: Date, to end: Date, now: Date = Date()) -> [ActivityInterval] {
        flush()
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

    private func append(_ kind: ActivityKind, from start: Date, to end: Date) {
        guard end > start else { return }
        journal.pending.append(ActivityInterval(kind: kind, startedAt: start, endedAt: end))
    }

    private func saveAndFlush() {
        sessionStore.save(activityJournal: journal)
        flush()
    }

    private func flush() {
        guard let activityStore, !journal.pending.isEmpty else { return }
        do {
            for interval in journal.pending {
                try activityStore.insert(interval)
            }
            journal.pending.removeAll()
            sessionStore.save(activityJournal: journal)
            storageFailed = false
        } catch {
            storageFailed = true
            NSLog("Kaskas: Failed to save activity history: %@", String(describing: error))
        }
    }
}
