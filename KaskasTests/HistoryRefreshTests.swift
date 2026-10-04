import Foundation
import SwiftData
import Testing
@testable import Kaskas

struct HistoryRefreshTests {
    @Test
    func sharedSnapshotMatchesIndependentChartsAcrossYearBoundary() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Istanbul"))
        let start = try #require(calendar.date(from: DateComponents(year: 2025, month: 12, day: 28)))
        let end = try #require(calendar.date(byAdding: .day, value: 7, to: start))
        let historyStart = try #require(calendar.date(byAdding: .day, value: -6, to: start))
        var intervals: [ActivityInterval] = []
        for distance in 0..<14 {
            let day = try #require(calendar.date(byAdding: .day, value: distance, to: historyStart))
            for kind in ActivityKind.allCases {
                intervals.append(ActivityInterval(kind: kind, startedAt: day.addingTimeInterval(23 * 3600),
                                                  endedAt: day.addingTimeInterval(25 * 3600)))
            }
        }
        // Replayed and overlapping history must retain elapsed-time semantics.
        intervals += [intervals[0], ActivityInterval(kind: .studying,
            startedAt: historyStart.addingTimeInterval(23.5 * 3600), endedAt: historyStart.addingTimeInterval(26 * 3600))]
        let distributionStart = try #require(calendar.date(byAdding: .day, value: 2, to: start))
        let snapshot = StatisticsChartSnapshot.make(intervals: intervals, trendWindow: (start, end),
            distributionWindow: (distributionStart, end), hourlyWindow: (start, distributionStart), year: 2026, calendar: calendar)
        let trendDays = ActivityStatistics.days(from: start, through: end, intervals: intervals, calendar: calendar)
        #expect(snapshot.trend.points == StudyTrendData.make(days: trendDays, intervals: intervals, calendar: calendar).points)
        #expect(snapshot.distributionDays == ActivityStatistics.days(from: distributionStart, through: end, intervals: intervals, calendar: calendar))
        #expect(snapshot.hourlyDays == ActivityStatistics.days(from: start, through: distributionStart, intervals: intervals, calendar: calendar))
        for day in snapshot.hourlyDays {
            #expect(snapshot.hourlyPoints.filter { $0.date == day.date }.map(\.minutes)
                    == ActivityStatistics.focusMinutesByHour(on: day.date, intervals: intervals, calendar: calendar))
        }
        let yearStart = try #require(calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)))
        let yearEnd = try #require(calendar.date(from: DateComponents(year: 2026, month: 12, day: 31)))
        let expectedYear = YearHeatmapData.make(year: 2026,
            days: ActivityStatistics.days(from: yearStart, through: yearEnd, intervals: intervals, calendar: calendar), calendar: calendar)
        #expect(snapshot.year.activityByDate == expectedYear.activityByDate)
        #expect(snapshot.year.weeks == expectedYear.weeks)
    }

    @Test(arguments: [(3, 8, 23.0), (11, 1, 25.0)])
    func hourlyAggregationRespectsDaylightSaving(month: Int, day: Int, hours: Double) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))
        let start = try #require(calendar.date(from: DateComponents(year: 2026, month: month, day: day)))
        let end = try #require(calendar.date(byAdding: .day, value: 1, to: start))
        let focus = ActivityInterval(kind: .studying, startedAt: start.addingTimeInterval(-3600), endedAt: end.addingTimeInterval(3600))
        let result = ActivityStatistics.focusMinutesByDay(from: start, through: start, intervals: [focus, focus], calendar: calendar)
        let minutes = try #require(result[start])
        #expect(minutes.count == 24)
        #expect(minutes.reduce(0, +) == hours * 60)
        #expect(minutes == ActivityStatistics.focusMinutesByHour(on: start, intervals: [focus, focus], calendar: calendar))
        #expect(result.count == 1)
    }

    @MainActor @Test
    func backgroundContextsReadSavedRecordsAndRespectWindowBounds() async throws {
        let container = try ModelContainer(for: ActivityRecord.self, AppUsageRecord.self, BreakRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let activities = ActivityStore(container: container)
        let usage = AppUsageStore(container: container)
        let breaks = BreakHistoryStore(container: container)
        let start = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let end = start.addingTimeInterval(3600)
        let focus = ActivityInterval(kind: .studying, startedAt: start.addingTimeInterval(-60), endedAt: end)
        try activities.insert(focus)
        try activities.insert(ActivityInterval(kind: .studying, startedAt: end, endedAt: end.addingTimeInterval(60)))
        let segment = AppUsageSegment(id: UUID(), app: ForegroundApp(bundleID: "example.app", name: "Example"),
            resolution: .unmatched, startedAt: start, endedAt: end)
        try usage.insert(segment)
        let entry = BreakHistoryEntry(id: "break", occurredAt: start, startedAt: start,
            focusStartedAt: nil, focusedDuration: nil, outcome: .completed, source: .manual)
        try breaks.insert(entry)
        #expect(try await activities.intervalsAsync(from: start, to: end) == [focus])
        #expect(try await usage.segmentsAsync(from: start, to: end) == [segment])
        #expect(try await breaks.entriesAsync(from: start, to: end) == [entry])
        #expect(try await activities.intervalsAsync(from: start.addingTimeInterval(-3600), to: focus.startedAt).isEmpty)
        #expect(try await breaks.entriesAsync(from: end, to: end.addingTimeInterval(3600)).isEmpty)
    }

    @MainActor @Test
    func asyncActivityReadPreservesBufferedHistoryAndLiveCursorWithoutWriting() async throws {
        let suite = "HistoryRefreshTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let sessionStore = SessionStore(defaults: defaults)
        let start = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let pending = ActivityInterval(kind: .studying, startedAt: start, endedAt: start.addingTimeInterval(600))
        let journal = ActivityJournal(cursor: ActivityCursor(kind: .breakTime,
            startedAt: pending.endedAt, checkpointAt: pending.endedAt), pending: [pending])
        sessionStore.save(activityJournal: journal)
        let recording = BufferedActivityRecording(persisted: [pending])
        let tracker = ActivityTracker(sessionStore: sessionStore, activityStore: recording)
        let now = start.addingTimeInterval(900)
        let values = await tracker.intervalsAsync(from: start, to: now, now: now)
        #expect(values == [pending, ActivityInterval(kind: .breakTime, startedAt: pending.endedAt, endedAt: now)])
        #expect(recording.inserts == 0)
        #expect(tracker.journal == journal)
    }

    @MainActor private final class BufferedActivityRecording: ActivityRecording {
        let persisted: [ActivityInterval]
        var inserts = 0
        init(persisted: [ActivityInterval]) { self.persisted = persisted }
        func insert(_ interval: ActivityInterval) throws { inserts += 1 }
        func intervals(from start: Date, to end: Date) throws -> [ActivityInterval] { persisted }
    }

}
