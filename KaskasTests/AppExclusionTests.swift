import Foundation
import SwiftData
import Testing
@testable import Kaskas

@MainActor
struct AppExclusionTests {
    private let start = Date(timeIntervalSinceReferenceDate: 1_000_000)
    private let work = ForegroundApp(bundleID: "com.apple.dt.Xcode", name: "Xcode")
    private let chat = ForegroundApp(bundleID: "com.example.chat", name: "Chat")

    private func usage(_ app: ForegroundApp, _ from: Double, _ to: Double, id: UUID = UUID()) -> AppUsageSegment {
        .init(id: id, app: app, resolution: .init(categoryID: "coding", source: .userRule, ruleKey: app.bundleID),
              startedAt: start.addingTimeInterval(from), endedAt: start.addingTimeInterval(to))
    }

    private func excluded(_ from: Double, _ to: Double) -> ExcludedUsageInterval {
        .init(id: UUID(), startedAt: start.addingTimeInterval(from), endedAt: start.addingTimeInterval(to))
    }

    private func study(_ from: Double, _ to: Double) -> ActivityInterval {
        .init(kind: .studying, startedAt: start.addingTimeInterval(from), endedAt: start.addingTimeInterval(to))
    }

    private var exclusions: AppExclusionSnapshot { .init(identifiers: [chat.bundleID!]) }

    @Test func twentyExcludedMinutesLeaveFiveAndBreakStillStartsAtTwentyFive() {
        var configuration = FocusConfiguration()
        configuration.focusDuration = 25 * 60
        let engine = SessionEngine(configuration: configuration, now: start)
        let history = [study(0, 25 * 60)]
        let projection = StudyTimeProjection(intervals: history, usage: [usage(work, 0, 5 * 60)],
                                             excluded: [excluded(5 * 60, 25 * 60)], exclusions: exclusions)
        let summary = CategoryUsageSummary.make(intervals: projection.intervals, usage: projection.usage,
                                                from: start, to: start.addingTimeInterval(25 * 60))
        #expect(summary.total == 5 * 60)
        #expect(summary.entries.first?.duration == summary.total)
        #expect(summary.undetected == 0)
        #expect(engine.snapshot(at: start.addingTimeInterval(24 * 60)).remaining == 60)
        var ticking = engine
        _ = ticking.send(.tick, at: start.addingTimeInterval(25 * 60))
        #expect(ticking.status.phase == .onBreak)
    }

    @Test func historicalExclusionIsReversibleButAnonymousTimeIsNot() {
        let history = [study(0, 1500)]
        let recorded = [usage(work, 0, 300), usage(chat, 300, 900)]
        let anonymous = [excluded(900, 1500)]
        let hidden = StudyTimeProjection(intervals: history, usage: recorded, excluded: anonymous, exclusions: exclusions)
        let restored = StudyTimeProjection(intervals: history, usage: recorded, excluded: anonymous, exclusions: .empty)
        #expect(duration(hidden.intervals) == 300)
        #expect(hidden.usage.map(\.app) == [work])
        #expect(duration(restored.intervals) == 900)
        #expect(restored.usage.count == 2)
    }

    @Test func unknownHistoricalTimeIsNotGuessed() {
        let projection = StudyTimeProjection(intervals: [study(0, 1500)], usage: [], excluded: [], exclusions: exclusions)
        #expect(duration(projection.intervals) == 1500)
    }

    @Test func overlappingAnonymousAndHistoricalVisitsAreSubtractedOnce() {
        let projection = StudyTimeProjection(intervals: [study(0, 1500), study(0, 1500)],
                                             usage: [usage(chat, 300, 1000)],
                                             excluded: [excluded(500, 1100), excluded(900, 1200)], exclusions: exclusions)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = ActivityStatistics.days(from: start, through: start, intervals: projection.intervals, calendar: calendar)
        #expect(day.first?.studying == 600)
    }

    @Test func historicalOverlapUsesTheSameWinnerAsCategoryReports() {
        let winner = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let loser = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let projection = StudyTimeProjection(intervals: [study(0, 1500)],
                                             usage: [usage(chat, 0, 1500, id: loser), usage(work, 0, 1500, id: winner)],
                                             excluded: [], exclusions: exclusions)
        #expect(duration(projection.intervals) == 1500)
        #expect(projection.usage.map(\.app) == [work])
    }

    @Test func exclusionsNeverSubtractBreaksOrMeetings() {
        let history = [study(0, 300), ActivityInterval(kind: .meeting, startedAt: start.addingTimeInterval(300),
                                                     endedAt: start.addingTimeInterval(900)), study(900, 1500)]
        let projection = StudyTimeProjection(intervals: history, usage: [], excluded: [excluded(200, 1000)], exclusions: .empty)
        #expect(duration(projection.intervals.filter { $0.kind == .studying }) == 700)
        #expect(projection.intervals.first { $0.kind == .meeting } == history[1])
    }

    @Test func longExcludedVisitDoesNotSplitSessionOrLoseItsAnnotation() throws {
        let suite = "AppExclusionTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SessionStore(defaults: defaults)
        let original = try #require(StudySessionGrouping.group([study(0, 1800)]).first)
        store.save(annotation: SessionAnnotation(note: "Keep this note"), for: original)
        let projection = StudyTimeProjection(intervals: original.intervals, usage: [],
                                             excluded: [excluded(300, 1500)], exclusions: .empty)
        let projected = try #require(projection.session(original))
        #expect(projected.id == original.id)
        #expect(projected.intervals == original.intervals)
        #expect(projected.focusedDuration == 600)
        #expect(projected.effectiveSegments?.count == 2)
        #expect(store.annotation(for: projected).note == "Keep this note")
        let allExcluded = StudyTimeProjection(intervals: original.intervals, usage: [], excluded: [excluded(0, 1800)], exclusions: .empty)
        #expect(allExcluded.session(original) == nil)
        #expect(store.annotation(for: original).note == "Keep this note")
    }

    @Test func dashboardAndStatisticsShareNetTimeAndHideExcludedSessions() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.startOfDay(for: start)
        let end = start.addingTimeInterval(1500)
        let history = [study(0, 1500)]
        let usage = [usage(work, 0, 300), usage(chat, 300, 1500)]
        let dashboard = try await DashboardRefreshSnapshot.make(intervals: history, usage: usage, breaks: [],
            date: date, weekStart: date, sessionEnd: end, calendar: calendar, exclusions: exclusions)
        let stats = try await StatisticsRefreshSnapshot.make(intervals: history, usage: usage, window: (date, date),
            categoryEnd: end, year: calendar.component(.year, from: date), calendar: calendar, period: .day, exclusions: exclusions)
        #expect(dashboard.day.sessions.count == 1)
        #expect(dashboard.day.sessions.first?.value.focusedDuration == 300)
        #expect(dashboard.day.sessions.first?.summary.usage.total == 300)
        #expect(dashboard.chart.days.first?.studying == 300)
        #expect(stats.categories.total == dashboard.day.usage.total)
        #expect(stats.chart.hourlyDays.first?.studying == 300)
        #expect(stats.chart.hourlyPoints.reduce(0) { $0 + $1.minutes } == 5)
        let empty = try await DashboardRefreshSnapshot.make(intervals: history, usage: [self.usage(chat, 0, 1500)], breaks: [],
            date: date, weekStart: date, sessionEnd: end, calendar: calendar, exclusions: exclusions)
        #expect(empty.day.sessions.isEmpty)
        #expect(empty.week.sessions.isEmpty)
        #expect(empty.day.usage.total == 0)
    }

    @Test func preferencesNormalizePersistAndDoNotChangeCategoryRules() throws {
        let suite = "AppExclusionTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = AppExclusionPreferences(defaults: defaults)
        preferences.add([.init(bundleID: " COM.EXAMPLE.CHAT ", name: "Chat"), .init(bundleID: "", name: "Unknown")])
        #expect(preferences.applications.count == 1)
        #expect(preferences.snapshot().contains(chat))
        #expect(!preferences.snapshot().contains(.init(bundleID: "other.chat", name: "Chat")))
        let registry = CategoryRegistry(defaults: defaults)
        registry.resetToDefaults()
        let restored = AppExclusionPreferences(defaults: defaults)
        #expect(restored.applications == preferences.applications)
        restored.remove(bundleID: " COM.EXAMPLE.CHAT ")
        #expect(restored.applications.isEmpty)
    }

    @Test func categoryDisabledStillExcludesAndStaleCallbacksAreRejected() throws {
        let suite = "AppExclusionTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SessionStore(defaults: defaults)
        store.automaticCategoryDetectionEnabled = false
        store.appExclusions.add([.init(bundleID: chat.bundleID!, name: chat.name)])
        let monitor = ExclusionMonitor(app: chat)
        var now = start
        let controller = AppUsageController(sessionStore: store, registry: CategoryRegistry(defaults: defaults),
                                            usageStore: nil, monitor: monitor, clock: { now })
        controller.setWorking(true, at: now)
        let stale = monitor.callback
        now = start.addingTimeInterval(1200)
        monitor.activate(work)
        now = start.addingTimeInterval(1500)
        controller.setWorking(false, at: now)
        stale?(chat)
        #expect(controller.segments(from: start, to: now, now: now).isEmpty)
        #expect(controller.excludedIntervals(from: start, to: now, now: now).first?.endedAt == start.addingTimeInterval(1200))
        #expect(store.loadAppUsageJournal().cursor == nil)
        #expect(store.loadAppUsageJournal().pending.isEmpty)
        #expect(store.loadExcludedUsageJournal().cursor == nil)
    }

    @Test func transitionsAndLivePreferenceChangesNeverRecordExcludedAppIdentity() throws {
        let suite = "AppExclusionTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SessionStore(defaults: defaults)
        let monitor = ExclusionMonitor(app: work)
        var now = start
        let controller = AppUsageController(sessionStore: store, registry: CategoryRegistry(defaults: defaults),
                                            usageStore: nil, monitor: monitor, clock: { now })
        controller.setWorking(true, at: now)
        now = start.addingTimeInterval(300)
        store.appExclusions.add([.init(bundleID: chat.bundleID!, name: chat.name)])
        monitor.activate(chat)
        #expect(store.loadAppUsageJournal().cursor == nil)
        #expect(store.loadAppUsageJournal().pending.allSatisfy { $0.app != chat })
        now = start.addingTimeInterval(1200)
        store.appExclusions.remove(bundleID: chat.bundleID!)
        now = start.addingTimeInterval(1500)
        controller.setWorking(false, at: now)
        let records = controller.segments(from: start, to: now, now: now)
        #expect(records.count == 2)
        #expect(records.first?.endedAt == start.addingTimeInterval(300))
        #expect(records.last?.startedAt == start.addingTimeInterval(1200))
        let anonymous = controller.excludedIntervals(from: start, to: now, now: now)
        #expect(anonymous.count == 1)
        #expect(anonymous.first?.startedAt == start.addingTimeInterval(300))
        #expect(anonymous.first?.endedAt == start.addingTimeInterval(1200))
        let journalData = try JSONEncoder().encode(store.loadExcludedUsageJournal())
        let json = try #require(String(data: journalData, encoding: .utf8))
        #expect(!json.contains(chat.bundleID!))
        #expect(!json.contains("appName"))
    }

    @Test func recoveryAndClockChangeStopAtLastVerifiedCheckpoint() throws {
        let suite = "AppExclusionTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SessionStore(defaults: defaults)
        let tracker = ExcludedUsageTracker(sessionStore: store, usageStore: nil)
        tracker.update(isExcluded: true, at: start)
        tracker.update(isExcluded: true, at: start.addingTimeInterval(30))
        let restored = ExcludedUsageTracker(sessionStore: store, usageStore: nil)
        #expect(restored.journal.cursor == nil)
        #expect(restored.journal.pending.first?.endedAt == start.addingTimeInterval(30))
        restored.update(isExcluded: true, at: start.addingTimeInterval(3600))
        restored.update(isExcluded: true, at: start.addingTimeInterval(3630))
        restored.clockDidChange()
        #expect(restored.journal.pending.last?.endedAt == start.addingTimeInterval(3630))
        #expect(restored.journal.cursor == nil)
    }

    @Test func persistenceIsIdempotentAndHistoryDeletionIncludesAnonymousRecords() async throws {
        let container = try ModelContainer(for: ActivityRecord.self, AppUsageRecord.self, BreakRecord.self, ExcludedUsageRecord.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let store = ExcludedUsageStore(container: container)
        let value = excluded(0, 1200)
        try await store.insertBatch([value, value])
        #expect(try await store.intervalsAsync(from: start, to: start.addingTimeInterval(1500)).count == 1)
        try await HistoryWriteWorker(container: container).deleteAllHistory()
        #expect(try await store.intervalsAsync(from: start, to: start.addingTimeInterval(1500)).isEmpty)
    }

    @Test func anonymousModelCanBeAddedToExistingHistoryWithoutLosingData() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ExclusionMigration-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("history.store")
        do {
            let old = try ModelContainer(for: ActivityRecord.self, AppUsageRecord.self, BreakRecord.self,
                                         configurations: ModelConfiguration(url: url))
            let context = ModelContext(old)
            context.insert(ActivityRecord(study(0, 300)))
            context.insert(AppUsageRecord(usage(work, 0, 300)))
            try context.save()
        }
        let updated = try ModelContainer(for: ActivityRecord.self, AppUsageRecord.self, BreakRecord.self, ExcludedUsageRecord.self,
                                         configurations: ModelConfiguration(url: url))
        let context = ModelContext(updated)
        #expect(try context.fetchCount(FetchDescriptor<ActivityRecord>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<AppUsageRecord>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<ExcludedUsageRecord>()) == 0)
    }

    @Test func midnightClippingKeepsDailyAndHourlyTotalsConsistent() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let midnight = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 5)))
        let a = midnight.addingTimeInterval(-300), b = midnight.addingTimeInterval(300)
        let history = [ActivityInterval(kind: .studying, startedAt: a, endedAt: b)]
        let excluded = [ExcludedUsageInterval(id: UUID(), startedAt: midnight.addingTimeInterval(-120), endedAt: midnight.addingTimeInterval(120))]
        let projection = StudyTimeProjection(intervals: history, usage: [], excluded: excluded, exclusions: .empty)
        let days = ActivityStatistics.days(from: a, through: b, intervals: projection.intervals, calendar: calendar)
        #expect(days.map(\.studying) == [180, 180])
        #expect(ActivityStatistics.focusMinutesByHour(on: midnight, intervals: projection.intervals, calendar: calendar).reduce(0, +) == 3)
    }

    @Test func failedAnonymousWritesKeepOutboxAndReadsDoNotRetry() async throws {
        let suite = "AppExclusionTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let database = ExclusionWriteStore()
        database.shouldFail = true
        let store = SessionStore(defaults: defaults)
        let tracker = ExcludedUsageTracker(sessionStore: store, usageStore: database)
        tracker.update(isExcluded: true, at: start)
        tracker.update(isExcluded: false, at: start.addingTimeInterval(30))
        await tracker.waitForPersistence()
        #expect(tracker.storageFailed)
        #expect(store.loadExcludedUsageJournal().pending.count == 1)
        _ = await tracker.intervalsAsync(from: start, to: start.addingTimeInterval(60), now: start.addingTimeInterval(60))
        #expect(database.attempts == 1)
        database.shouldFail = false
        tracker.update(isExcluded: false, at: start.addingTimeInterval(60))
        await tracker.waitForPersistence()
        #expect(database.attempts == 2)
        #expect(database.records.count == 1)
        #expect(tracker.journal.pending.isEmpty)
        #expect(!tracker.storageFailed)
    }

    @Test func historyResetDiscardsAnonymousOutboxAndRestartsActiveCursor() async throws {
        let suite = "AppExclusionTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let database = ExclusionWriteStore()
        let tracker = ExcludedUsageTracker(sessionStore: SessionStore(defaults: defaults), usageStore: database)
        tracker.suspendPersistence()
        tracker.update(isExcluded: true, at: start)
        tracker.update(isExcluded: false, at: start.addingTimeInterval(30))
        tracker.update(isExcluded: true, at: start.addingTimeInterval(40))
        tracker.resetHistory(at: start.addingTimeInterval(60))
        tracker.resumePersistence()
        await tracker.waitForPersistence()
        #expect(database.records.isEmpty)
        #expect(tracker.journal.pending.isEmpty)
        #expect(tracker.journal.cursor?.startedAt == start.addingTimeInterval(60))
        tracker.update(isExcluded: false, at: start.addingTimeInterval(70))
        await tracker.waitForPersistence()
        #expect(database.records.first?.startedAt == start.addingTimeInterval(60))
        #expect(database.records.first?.endedAt == start.addingTimeInterval(70))
    }

    @Test func emptyCheckpointsDoNotWriteButClosingActiveUsageDoes() throws {
        let suite = "AppExclusionTests.\(UUID())"
        let defaults = try #require(JournalCountingDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SessionStore(defaults: defaults)
        let tracker = AppUsageTracker(sessionStore: store, usageStore: nil)
        defaults.journalWrites = 0
        for offset in 0..<100 {
            tracker.update(app: nil, at: start.addingTimeInterval(Double(offset) * 30))
        }
        #expect(defaults.journalWrites == 0)

        tracker.update(app: .init(bundleID: "work.app", name: "Work"), at: start)
        tracker.update(app: nil, at: start.addingTimeInterval(60))
        #expect(defaults.journalWrites == 2)
        #expect(store.loadAppUsageJournal().cursor == nil)
        #expect(store.loadAppUsageJournal().pending.first?.endedAt == start.addingTimeInterval(60))
    }

    @Test func reusedTimelinePreservesOverlapWinnersAndWindowClipping() {
        func segment(_ id: Int, _ app: String, _ from: Double, _ to: Double) -> AppUsageSegment {
            .init(id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", id))!,
                  app: .init(bundleID: app, name: app), resolution: .unmatched,
                  startedAt: start.addingTimeInterval(from), endedAt: start.addingTimeInterval(to))
        }
        let history = [ActivityInterval(kind: .studying, startedAt: start, endedAt: start.addingTimeInterval(600))]
        let usage = [segment(2, "work.app", 0, 300), segment(1, "excluded.app", 0, 200),
                     segment(3, "work.app", 200, 400), segment(4, "other.app", 450, 600)]
        for exclusions in [AppExclusionSnapshot.empty, .init(identifiers: ["excluded.app"])] {
            let projection = StudyTimeProjection(intervals: history, usage: usage, excluded: [], exclusions: exclusions)
            for window in [(0.0, 600.0), (100.0, 500.0), (400.0, 450.0), (600.0, 700.0)] {
                let from = start.addingTimeInterval(window.0), to = start.addingTimeInterval(window.1)
                let reused = projection.timeline.summary(intervals: projection.intervals, from: from, to: to)
                let rebuilt = CategoryUsageSummary.make(intervals: projection.intervals, usage: projection.usage, from: from, to: to)
                #expect(reused == rebuilt)
            }
            let summary = projection.timeline.summary(intervals: projection.intervals, from: start, to: start.addingTimeInterval(600))
            #expect(summary.total == (exclusions.identifiers.isEmpty ? 600 : 400))
            #expect(summary.unrecordedDuration == 50)
            #expect(summary.apps.first { $0.app.bundleID == "work.app" }?.duration == 200)
        }
    }

    private func duration(_ values: [ActivityInterval]) -> Double {
        values.reduce(0) { $0 + $1.endedAt.timeIntervalSince($1.startedAt) }
    }
}

@MainActor
private final class ExclusionMonitor: ForegroundAppMonitoring {
    var app: ForegroundApp?
    var callback: ((ForegroundApp?) -> Void)?
    init(app: ForegroundApp?) { self.app = app }
    func start(onChange: @escaping (ForegroundApp?) -> Void) { callback = onChange; onChange(app) }
    func stop() { callback = nil }
    func sample() -> ForegroundApp? { app }
    func activate(_ app: ForegroundApp?) { self.app = app; callback?(app) }
}

@MainActor
private final class ExclusionWriteStore: ExcludedUsageRecording {
    var records: [ExcludedUsageInterval] = []
    var attempts = 0
    var shouldFail = false

    func insertBatch(_ values: [ExcludedUsageInterval]) async throws {
        attempts += 1
        if shouldFail { throw CocoaError(.fileWriteUnknown) }
        records.append(contentsOf: values)
    }

    func intervals(from start: Date, to end: Date) throws -> [ExcludedUsageInterval] {
        records.filter { $0.startedAt < end && $0.endedAt > start }
    }
}

nonisolated private final class JournalCountingDefaults: UserDefaults, @unchecked Sendable {
    var journalWrites = 0
    override func set(_ value: Any?, forKey key: String) {
        if key == "appUsageJournal" { journalWrites += 1 }
        super.set(value, forKey: key)
    }
}

