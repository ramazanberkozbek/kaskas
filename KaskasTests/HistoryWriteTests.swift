import Foundation
import SwiftData
import Testing
@testable import Kaskas

@MainActor
struct HistoryWriteTests {
    private final class SuspendedUsageStore: AppUsageRecording {
        var batches: [[AppUsageSegment]] = []
        var continuation: CheckedContinuation<Void, any Error>?
        var records: [AppUsageSegment] = []
        func insert(_ segment: AppUsageSegment) throws { Issue.record("Synchronous insertion used") }
        func insertBatch(_ values: [AppUsageSegment]) async throws {
            batches.append(values)
            try await withCheckedThrowingContinuation { continuation = $0 }
            records.append(contentsOf: values)
        }
        func segments(from start: Date, to end: Date) throws -> [AppUsageSegment] { records }
        func finish() { continuation?.resume(); continuation = nil }
    }

    @Test func foregroundEventsKeepTimestampsAndNewPendingRecordsDuringCommit() async throws {
        let suite = "HistoryWriteTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let sessionStore = SessionStore(defaults: defaults)
        let database = SuspendedUsageStore()
        let tracker = AppUsageTracker(sessionStore: sessionStore, usageStore: database)
        let start = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let firstApp = ForegroundApp(bundleID: "first", name: "First")
        let secondApp = ForegroundApp(bundleID: "second", name: "Second")
        tracker.update(app: firstApp, at: start)
        tracker.update(app: secondApp, at: start.addingTimeInterval(10))
        // The notification returns before any database operation starts.
        #expect(database.batches.isEmpty)
        #expect(sessionStore.loadAppUsageJournal().pending.first?.endedAt == start.addingTimeInterval(10))
        while database.continuation == nil { await Task.yield() }
        tracker.update(app: nil, at: start.addingTimeInterval(20))
        #expect(tracker.journal.pending.count == 2)
        database.finish()
        while database.batches.count < 2 { await Task.yield() }
        #expect(tracker.journal.pending.count == 1)
        #expect(tracker.journal.pending.first?.app == secondApp)
        #expect(sessionStore.loadAppUsageJournal().pending == tracker.journal.pending)
        database.finish()
        await tracker.waitForPersistence()
        #expect(tracker.journal.pending.isEmpty)
        #expect(database.records.map(\.startedAt) == [start, start.addingTimeInterval(10)])
        #expect(database.records.map(\.endedAt) == [start.addingTimeInterval(10), start.addingTimeInterval(20)])
    }

    @Test func historyReadsDoNotRetryFailedWrites() async throws {
        let suite = "HistoryWriteTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let database = SuspendedUsageStore()
        let tracker = AppUsageTracker(sessionStore: SessionStore(defaults: defaults), usageStore: database)
        let start = Date(timeIntervalSinceReferenceDate: 1_000_000)
        tracker.update(app: ForegroundApp(bundleID: "first", name: "First"), at: start)
        tracker.update(app: nil, at: start.addingTimeInterval(10))
        while database.continuation == nil { await Task.yield() }
        database.continuation?.resume(throwing: CocoaError(.fileWriteUnknown))
        database.continuation = nil
        await tracker.waitForPersistence()
        #expect(tracker.storageFailed)
        #expect(tracker.segments(from: start, to: start.addingTimeInterval(30), now: start).count == 1)
        #expect(await tracker.segmentsAsync(from: start, to: start.addingTimeInterval(30), now: start).count == 1)
        await Task.yield()
        #expect(database.batches.count == 1)
        #expect(tracker.journal.pending.count == 1)
    }

    private final class SuspendedBreakStore: BreakHistoryRecording {
        var batches: [[BreakHistoryEntry]] = []
        var continuation: CheckedContinuation<Void, Never>?
        func insert(_ entry: BreakHistoryEntry) throws { Issue.record("Synchronous insertion used") }
        func insertBatch(_ values: [BreakHistoryEntry]) async throws {
            batches.append(values)
            await withCheckedContinuation { continuation = $0 }
        }
        func finish() { continuation?.resume(); continuation = nil }
    }

    @Test func breakOutboxPreservesNewEventsAndVisibleTotalsDuringCommit() async throws {
        let suite = "HistoryWriteTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SessionStore(defaults: defaults)
        let database = SuspendedBreakStore()
        let persistence = SessionPersistence(store: store, historyStore: database)
        let start = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let state = SessionEngine(now: start).state
        let entries = (0..<2).map { index in
            BreakHistoryEntry(id: "break-\(index)", occurredAt: start.addingTimeInterval(Double(index)),
                startedAt: nil, focusStartedAt: nil, focusedDuration: nil, outcome: .completed, source: .manual)
        }
        persistence.save(state: state, record: entries[0])
        while database.continuation == nil { await Task.yield() }
        persistence.save(state: state, record: entries[1])
        // A fresh SessionStore can recover both entries even before either commit.
        #expect(SessionStore(defaults: defaults).loadPendingHistoryEntries() == entries)
        database.finish()
        while database.batches.count < 2 { await Task.yield() }
        #expect(persistence.bufferedHistoryEntries == [entries[1]])
        let visible = SessionPersistence.mergeEntries([entries[0], entries[1]],
            buffered: persistence.bufferedHistoryEntries, from: start, to: start.addingTimeInterval(10))
        #expect(visible == entries)
        #expect(store.loadPendingHistoryEntries() == [entries[1]])
        database.finish()
        await persistence.waitForPersistence()
        #expect(store.loadPendingHistoryEntries().isEmpty)
    }

    @Test func suspendedWriterCannotReplayDeletedPendingHistory() async throws {
        let suite = "HistoryDeletionRaceTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SessionStore(defaults: defaults)
        let database = SuspendedUsageStore()
        let tracker = AppUsageTracker(sessionStore: store, usageStore: database)
        let start = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let app = ForegroundApp(bundleID: "test", name: "Test")
        tracker.update(app: app, at: start)
        tracker.update(app: nil, at: start.addingTimeInterval(10))
        while database.continuation == nil { await Task.yield() }
        tracker.suspendPersistence()
        tracker.update(app: app, at: start.addingTimeInterval(20))
        tracker.update(app: nil, at: start.addingTimeInterval(30))
        database.finish()
        await tracker.waitForPersistence()
        #expect(database.batches.count == 1)
        #expect(tracker.journal.pending.count == 1)
        database.records.removeAll()
        tracker.resetHistory(at: start.addingTimeInterval(40))
        tracker.resumePersistence()
        await tracker.waitForPersistence()
        #expect(database.records.isEmpty)
        #expect(database.batches.count == 1)
        #expect(store.loadAppUsageJournal().pending.isEmpty)
    }

    @Test func deletingHistoryClearsDatabaseOutboxesNotesAndCounters() async throws {
        let suite = "HistoryDeletionTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SessionStore(defaults: defaults)
        var configuration = store.loadConfiguration()
        configuration.idleDetectionEnabled = false
        configuration.pauseDuringMeetings = false
        configuration.focusDuration = 1200
        store.save(configuration: configuration)
        let container = try ModelContainer(for: ActivityRecord.self, AppUsageRecord.self, BreakRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let activities = ActivityStore(container: container)
        let usage = AppUsageStore(container: container)
        let breaks = BreakHistoryStore(container: container)
        let start = Date().addingTimeInterval(-600)
        let interval = ActivityInterval(kind: .studying, startedAt: start, endedAt: start.addingTimeInterval(60))
        let entry = BreakHistoryEntry(id: "old-break", occurredAt: start.addingTimeInterval(60),
            startedAt: start, focusStartedAt: start, focusedDuration: 60, outcome: .completed, source: .manual)
        let segment = AppUsageSegment(id: UUID(), app: ForegroundApp(bundleID: "test", name: "Test"),
            resolution: .unmatched, startedAt: interval.startedAt, endedAt: interval.endedAt)
        try await activities.insert(interval)
        try await usage.insert(segment)
        try await breaks.insert(entry)
        store.save(activityJournal: ActivityJournal(cursor: ActivityCursor(kind: .studying,
            startedAt: start, checkpointAt: Date()), pending: [interval]))
        store.save(appUsageJournal: AppUsageJournal(cursor: nil, pending: [segment]))
        store.save(pendingHistoryEntries: [entry])
        store.save(annotation: SessionAnnotation(note: "Old note"), for: interval)
        var engine = SessionEngine(configuration: configuration, now: start)
        engine.completedBreaks = 4
        engine.completedBreaksDay = Calendar.current.startOfDay(for: Date())
        store.save(state: engine.state)
        let controller = SessionController(store: store, historyStore: breaks,
            activityStore: activities, appUsageStore: usage)
        try await controller.deleteHistory()
        await controller.waitForScreenTimeRefresh()
        let end = Date().addingTimeInterval(1)
        #expect(try await activities.intervalsAsync(from: start, to: end).isEmpty)
        #expect(try await usage.segmentsAsync(from: start, to: end).isEmpty)
        #expect(try await breaks.entriesAsync(from: start, to: end).isEmpty)
        #expect(store.loadPendingHistoryEntries().isEmpty)
        #expect(store.loadActivityJournal().pending.isEmpty)
        #expect(store.loadAppUsageJournal().pending.isEmpty)
        #expect(store.loadActivityJournal().cursor!.startedAt > start)
        #expect(store.annotation(for: interval).isEmpty)
        #expect(store.loadConfiguration().focusDuration == 1200)
        #expect(store.loadSessionState()?.completedBreaks == 0)
        #expect(controller.breaksTakenToday(at: Date()) == 0)
        #expect(controller.historyRevision == 1)
        #expect(!controller.isDeletingHistory)
        #expect(controller.screenTimeToday() < 5)
    }

    @Test func workerBatchesReplayIdempotentlyAcrossQueryChunks() async throws {
        let container = try ModelContainer(for: ActivityRecord.self, AppUsageRecord.self, BreakRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let activities = ActivityStore(container: container)
        let usage = AppUsageStore(container: container)
        let breaks = BreakHistoryStore(container: container)
        let start = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let intervals = (0..<300).map { index in
            ActivityInterval(kind: .studying, startedAt: start.addingTimeInterval(Double(index * 10)),
                endedAt: start.addingTimeInterval(Double(index * 10 + 5)))
        }
        let segments = intervals.map { interval in
            AppUsageSegment(id: UUID(), app: ForegroundApp(bundleID: "test", name: "Test"), resolution: .unmatched,
                startedAt: interval.startedAt, endedAt: interval.endedAt)
        }
        let entries = intervals.map { interval in
            BreakHistoryEntry(id: interval.id, occurredAt: interval.endedAt, startedAt: interval.startedAt,
                focusStartedAt: nil, focusedDuration: nil, outcome: .completed, source: .manual)
        }
        // Also repeat values inside one batch and across a chunk boundary.
        for _ in 0..<2 {
            try await activities.insertBatch(intervals + intervals)
            try await usage.insertBatch(segments + segments)
            try await breaks.insertBatch(entries + entries)
        }
        let end = start.addingTimeInterval(4000)
        #expect(try await activities.intervalsAsync(from: start, to: end) == intervals)
        #expect(try await usage.segmentsAsync(from: start, to: end) == segments)
        #expect(try await breaks.entriesAsync(from: start, to: end) == entries)
    }
}
