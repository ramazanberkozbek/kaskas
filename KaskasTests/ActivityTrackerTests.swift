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
    func databaseInsertionIsIdempotent() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: BreakRecord.self, ActivityRecord.self, configurations: configuration)
        let store = ActivityStore(container: container)
        let start = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let interval = ActivityInterval(kind: .studying, startedAt: start, endedAt: start.addingTimeInterval(600))

        try store.insert(interval)
        try store.insert(interval)

        #expect(try store.intervals(from: start, to: start.addingTimeInterval(1200)) == [interval])
    }
}
