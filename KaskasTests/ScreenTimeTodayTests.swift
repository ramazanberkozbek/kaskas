import Foundation
import Testing
@testable import Kaskas

@MainActor
struct ScreenTimeTodayTests {
    private func makeStore() throws -> (SessionStore, UserDefaults, String) {
        let suite = "ScreenTimeTodayTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        return (SessionStore(defaults: defaults), defaults, suite)
    }

    @Test
    func coldAndWarmReadsArePureAndCompletedHistoryIsDeduplicated() async throws {
        let (store, defaults, suite) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        let day = Calendar.current.startOfDay(for: Date())
        let now = day.addingTimeInterval(3600)
        let completed = ActivityInterval(kind: .studying, startedAt: day.addingTimeInterval(-60),
                                         endedAt: day.addingTimeInterval(600))
        let overlap = ActivityInterval(kind: .studying, startedAt: day.addingTimeInterval(300),
                                       endedAt: day.addingTimeInterval(900))
        let journal = ActivityJournal(cursor: ActivityCursor(kind: .studying,
            startedAt: day.addingTimeInterval(1800), checkpointAt: now), pending: [completed, overlap])
        store.save(activityJournal: journal)
        let recording = Recording(persisted: [completed])
        let controller = SessionController(store: store, activityStore: recording, now: now)

        #expect(controller.screenTimeToday(at: now) == 1800)
        #expect(controller.screenTimeToday(at: now.addingTimeInterval(1)) == 1801)
        #expect(recording.syncReads == 0)
        #expect(recording.asyncReads == 0)
        #expect(!controller.activityStorageFailed)
        await controller.waitForScreenTimeRefresh()
        #expect(controller.screenTimeToday(at: now) == 2700)
        #expect(recording.asyncReads == 1)
        for second in 0..<100 {
            controller.refreshScreenTimeToday(at: now.addingTimeInterval(Double(second)))
            #expect(controller.screenTimeToday(at: now.addingTimeInterval(Double(second))) == 2700 + Double(second))
        }
        await controller.waitForScreenTimeRefresh()
        #expect(recording.asyncReads == 1)
        #expect(recording.syncReads == 0)
        #expect(recording.inserts == 0)
        #expect(store.loadActivityJournal() == journal)
    }

    @Test
    func unchangedActivityReusesCacheAndTransitionRefreshesCompletedTime() async throws {
        let (store, defaults, suite) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        var configuration = store.loadConfiguration()
        configuration.idleDetectionEnabled = false
        configuration.pauseDuringMeetings = false
        store.save(configuration: configuration)
        let recording = Recording()
        let controller = SessionController(store: store, activityStore: recording)
        controller.start()
        defer { controller.stop() }
        await controller.waitForScreenTimeRefresh()
        let startedAt = try #require(controller.activeStudyingStartedAt)
        let readCount = recording.asyncReads
        // Foreground ticks do not complete the studying interval.
        controller.reconcile(at: startedAt.addingTimeInterval(30))
        controller.reconcile(at: startedAt.addingTimeInterval(60))
        await controller.waitForScreenTimeRefresh()
        #expect(recording.asyncReads == readCount)
        #expect(controller.screenTimeToday(at: startedAt.addingTimeInterval(60)) == 60)
        controller.systemWillSleep(at: startedAt.addingTimeInterval(120))
        await controller.waitForScreenTimeRefresh()
        #expect(recording.asyncReads == readCount + 1)
        #expect(controller.activeStudyingStartedAt == nil)
        #expect(controller.screenTimeToday(at: startedAt.addingTimeInterval(180)) == 120)
        controller.systemDidWake(at: startedAt.addingTimeInterval(240))
        await controller.waitForScreenTimeRefresh()
        #expect(controller.screenTimeToday(at: startedAt.addingTimeInterval(300)) == 180)
    }

    @Test
    func dayRolloverRejectsStaleResultEvenWhenReadIgnoresCancellation() async throws {
        let (store, defaults, suite) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        let day = Calendar.current.startOfDay(for: Date())
        let tomorrow = try #require(Calendar.current.date(byAdding: .day, value: 1, to: day))
        let recording = SuspendedRecording()
        let controller = SessionController(store: store, activityStore: recording, now: day.addingTimeInterval(3600))
        await recording.waitForRequests(1)
        controller.refreshScreenTimeToday(at: tomorrow.addingTimeInterval(3600))
        await recording.waitForRequests(2)
        recording.complete(1, with: [ActivityInterval(kind: .studying, startedAt: tomorrow, endedAt: tomorrow.addingTimeInterval(600))])
        await controller.waitForScreenTimeRefresh()
        #expect(controller.screenTimeToday(at: tomorrow.addingTimeInterval(3600)) == 600)
        #expect(controller.screenTimeToday(at: day.addingTimeInterval(3600)) == 0)
        recording.complete(0, with: [ActivityInterval(kind: .studying, startedAt: day, endedAt: day.addingTimeInterval(900))])
        // Drain the cancelled request before checking it cannot overwrite the new day.
        await recording.waitForReturns(2)
        #expect(controller.screenTimeToday(at: tomorrow.addingTimeInterval(3600)) == 600)
        #expect(recording.syncReads == 0)
    }

    @Test
    func inFlightRefreshDoesNotRetainController() async throws {
        let (store, defaults, suite) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        let recording = SuspendedRecording()
        var controller: SessionController? = SessionController(store: store, activityStore: recording)
        weak var weakController = controller
        await recording.waitForRequests(1)
        controller = nil
        #expect(weakController == nil)
        recording.complete(0, with: [])
        await recording.waitForReturns(1)
    }

    @Test
    func completedRevisionIgnoresCheckpointsAndPersistenceAcknowledgements() async throws {
        let (store, defaults, suite) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        let recording = Recording()
        let tracker = ActivityTracker(sessionStore: store, activityStore: recording)
        let start = Date()
        tracker.resume(as: .studying, at: start)
        tracker.update(to: .studying, at: start.addingTimeInterval(30))
        #expect(tracker.completedIntervalsRevision == 0)
        tracker.update(to: .breakTime, at: start.addingTimeInterval(60))
        #expect(tracker.completedIntervalsRevision == 1)
        let completed = await tracker.intervalsAsync(from: start, to: start.addingTimeInterval(120),
            now: start.addingTimeInterval(120), includeActiveCursor: false)
        #expect(completed == [ActivityInterval(kind: .studying, startedAt: start, endedAt: start.addingTimeInterval(60))])
        await tracker.waitForPersistence()
        #expect(tracker.completedIntervalsRevision == 1)
        tracker.update(to: .breakTime, at: start.addingTimeInterval(120))
        #expect(tracker.completedIntervalsRevision == 1)
    }

    private class Recording: ActivityRecording {
        var persisted: [ActivityInterval]
        var syncReads = 0
        var asyncReads = 0
        var inserts = 0
        init(persisted: [ActivityInterval] = []) { self.persisted = persisted }
        func insert(_ interval: ActivityInterval) async throws {
            inserts += 1
            persisted.append(interval)
        }
        func intervals(from start: Date, to end: Date) throws -> [ActivityInterval] {
            syncReads += 1
            throw ReadError.unexpectedSynchronousRead
        }
        func intervalsAsync(from start: Date, to end: Date) async throws -> [ActivityInterval] {
            asyncReads += 1
            return persisted.filter { $0.startedAt < end && $0.endedAt > start }
        }
    }

    private final class SuspendedRecording: Recording {
        var requests: [CheckedContinuation<[ActivityInterval], Never>] = []
        var returns = 0
        override func intervalsAsync(from start: Date, to end: Date) async throws -> [ActivityInterval] {
            let result = await withCheckedContinuation { requests.append($0) }
            returns += 1
            return result
        }
        func complete(_ index: Int, with values: [ActivityInterval]) { requests[index].resume(returning: values) }
        func waitForRequests(_ count: Int) async {
            while requests.count < count { await Task.yield() }
        }
        func waitForReturns(_ count: Int) async {
            while returns < count { await Task.yield() }
        }
    }

    private enum ReadError: Error { case unexpectedSynchronousRead }
}
