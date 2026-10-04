import Foundation
import SwiftData
import Testing
@testable import Kaskas

@MainActor
struct ActivityTrackerTests {
    private func total(_ kind: ActivityKind, in intervals: [ActivityInterval]) -> TimeInterval {
        intervals.filter { $0.kind == kind }
            .map { $0.endedAt.timeIntervalSince($0.startedAt) }
            .reduce(0, +)
    }

    private func makeSessionStore() throws -> (SessionStore, UserDefaults, String) {
        let suiteName = "ActivityTrackerTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        return (SessionStore(defaults: defaults), defaults, suiteName)
    }

    @Test
    func recordsStudyBreakAndSleepWithoutCountingSleepAsStudy() throws {
        let (sessionStore, defaults, suiteName) = try makeSessionStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let tracker = ActivityTracker(sessionStore: sessionStore, activityStore: nil)
        let start = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let breakAt = start.addingTimeInterval(45 * 60)
        let sleepAt = breakAt.addingTimeInterval(60)
        let wakeAt = sleepAt.addingTimeInterval(2 * 60 * 60)

        tracker.resume(as: .studying, at: start)
        tracker.update(to: .breakTime, at: breakAt)
        tracker.update(to: .computerInactive, at: sleepAt)
        tracker.update(to: .studying, at: wakeAt)

        let intervals = tracker.intervals(from: start, to: wakeAt.addingTimeInterval(1), now: wakeAt)
        let studying = total(.studying, in: intervals)
        let breakTime = total(.breakTime, in: intervals)
        let computerInactive = total(.computerInactive, in: intervals)
        #expect(studying == 45 * 60)
        #expect(breakTime == 60)
        #expect(computerInactive == 2 * 60 * 60)
    }

    @Test
    func restartAfterCrashAssignsGapToPausedTime() throws {
        let (sessionStore, defaults, suiteName) = try makeSessionStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let start = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let checkpoint = start.addingTimeInterval(25 * 60)
        let reopen = checkpoint.addingTimeInterval(3 * 60 * 60)

        let original = ActivityTracker(sessionStore: sessionStore, activityStore: nil)
        original.resume(as: .studying, at: start)
        original.update(to: .studying, at: checkpoint)

        let restored = ActivityTracker(sessionStore: sessionStore, activityStore: nil)
        restored.resume(as: .studying, at: reopen)
        let intervals = restored.intervals(from: start, to: reopen.addingTimeInterval(1), now: reopen)

        #expect(intervals.first(where: { $0.kind == .studying })?.endedAt == checkpoint)
        #expect(intervals.first(where: { $0.kind == .kaskasPaused })?.startedAt == checkpoint)
        #expect(intervals.first(where: { $0.kind == .kaskasPaused })?.endedAt == reopen)
    }

    @Test
    func meetingIsRecordedSeparatelyFromFocusAndManualPause() throws {
        let (sessionStore, defaults, suiteName) = try makeSessionStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: BreakRecord.self, ActivityRecord.self, configurations: configuration)
        let tracker = ActivityTracker(sessionStore: sessionStore, activityStore: ActivityStore(container: container))
        let start = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let meetingStart = start.addingTimeInterval(5 * 60)
        let meetingEnd = meetingStart.addingTimeInterval(10 * 60)
        let end = meetingEnd.addingTimeInterval(2 * 60)

        tracker.resume(as: .studying, at: start)
        tracker.update(to: .meeting, at: meetingStart)
        tracker.update(to: .studying, at: meetingEnd)
        tracker.update(to: .studying, at: end)

        let intervals = tracker.intervals(from: start, to: end, now: end)
        let today = try #require(ActivityStatistics.days(from: start, through: start, intervals: intervals).first)
        #expect(today.studying == 7 * 60)
        #expect(today.meeting == 10 * 60)
        #expect(today.kaskasPaused == 0)
        #expect(today.breakTime == 0)
    }

    @Test
    func crashDuringMeetingDoesNotAssumeMeetingContinuedWhileClosed() throws {
        let (sessionStore, defaults, suiteName) = try makeSessionStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let start = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let checkpoint = start.addingTimeInterval(5 * 60)
        let reopen = checkpoint.addingTimeInterval(30 * 60)

        let original = ActivityTracker(sessionStore: sessionStore, activityStore: nil)
        original.resume(as: .meeting, at: start)
        original.update(to: .meeting, at: checkpoint)

        let restored = ActivityTracker(sessionStore: sessionStore, activityStore: nil)
        restored.resume(as: .studying, at: reopen)
        let intervals = restored.intervals(from: start, to: reopen, now: reopen)

        #expect(total(.meeting, in: intervals) == 5 * 60)
        #expect(total(.kaskasPaused, in: intervals) == 30 * 60)
    }

    @Test
    func acceptedIdleBreakSplitsStudyBreakAndNewStudyWithoutOverlap() throws {
        let (sessionStore, defaults, suiteName) = try makeSessionStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let tracker = ActivityTracker(sessionStore: sessionStore, activityStore: nil)
        let start = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let idleAt = start.addingTimeInterval(12 * 60)
        let returnedAt = idleAt.addingTimeInterval(3 * 60)
        let end = returnedAt.addingTimeInterval(2 * 60)

        tracker.resume(as: .studying, at: start)
        tracker.update(to: .computerInactive, at: idleAt)
        tracker.update(to: .breakTime, at: idleAt)
        tracker.update(to: .studying, at: returnedAt)
        tracker.update(to: .studying, at: end)

        let intervals = tracker.intervals(from: start, to: end, now: end)
        #expect(total(.studying, in: intervals) == 14 * 60)
        #expect(total(.breakTime, in: intervals) == 3 * 60)
        #expect(total(.computerInactive, in: intervals) == 0)
    }

    @Test
    func databaseInsertionIsIdempotent() async throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: BreakRecord.self, ActivityRecord.self, configurations: configuration)
        let store = ActivityStore(container: container)
        let start = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let interval = ActivityInterval(kind: .studying, startedAt: start, endedAt: start.addingTimeInterval(600))

        try await store.insert(interval)
        try await store.insert(interval)

        #expect(try store.intervals(from: start, to: start.addingTimeInterval(1200)) == [interval])
    }
}
