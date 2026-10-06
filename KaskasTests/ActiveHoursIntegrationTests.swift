import Foundation
import Testing
@testable import Kaskas

@MainActor
struct ActiveHoursIntegrationTests {
    @Test(arguments: [false, true])
    func recordingFollowsTheTrackingPreferenceAtWindowBoundaries(pausesTracking: Bool) throws {
        let suite = "ActiveHoursIntegrationTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SessionStore(defaults: defaults)
        let calendar = Calendar.current
        let day = calendar.date(byAdding: .day, value: 2, to: Date())!
        let start = calendar.date(bySettingHour: 17, minute: 50, second: 0, of: day)!
        let end = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: day)!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: day)!
        let nextStart = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow)!
        var clock = start
        let config = FocusConfiguration(
            activeHours: ActiveHoursSchedule(isEnabled: true, weekdays: Set(1...7), endMinute: 18 * 60, pausesTracking: pausesTracking),
            focusDuration: 3600, microRemindersEnabled: false, pauseDuringMeetings: false,
            pauseWhileTyping: false, pauseDuringVideo: false, idleDetectionEnabled: false)
        store.save(configuration: config)
        store.automaticCategoryDetectionEnabled = true
        let monitor = HoursForegroundMonitor()
        let controller = SessionController(store: store, now: start, foregroundAppMonitor: monitor, appUsageClock: { clock })
        controller.start(at: start)
        defer { controller.stop(at: clock) }
        #expect(store.loadAppUsageJournal().cursor != nil)
        #expect(controller.activeStudyingStartedAt != nil)
        clock = end
        controller.reconcile(at: end)
        #expect(controller.sessionSnapshot.outsideActiveHours)
        #expect((controller.activeStudyingStartedAt == nil) == pausesTracking)
        #expect((store.loadAppUsageJournal().cursor == nil) == pausesTracking)
        if pausesTracking {
            #expect(monitor.callback == nil)
            let usage = controller.appUsage.segments(from: start, to: end.addingTimeInterval(3600), now: end.addingTimeInterval(3600))
            #expect(usage.reduce(0) { $0 + $1.endedAt.timeIntervalSince($1.startedAt) } == 600)
            let studying = controller.activityIntervals(from: start, to: end.addingTimeInterval(3600), now: end.addingTimeInterval(3600))
                .filter { $0.kind == .studying }
            #expect(studying.reduce(0) { $0 + $1.endedAt.timeIntervalSince($1.startedAt) } == 600)
        } else {
            #expect(monitor.callback != nil)
        }
        clock = nextStart
        controller.reconcile(at: nextStart)
        #expect(!controller.sessionSnapshot.outsideActiveHours)
        #expect(store.loadAppUsageJournal().cursor != nil)
        #expect(controller.activeStudyingStartedAt != nil)
        #expect(controller.sessionSnapshot.endsAt == nextStart.addingTimeInterval(3600))
    }

    @Test func lateCallbacksAndSchedulerStillStopRecordingAtTheBoundary() throws {
        let suite = "ActiveHoursIntegrationTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SessionStore(defaults: defaults)
        let calendar = Calendar.current
        let day = calendar.date(byAdding: .day, value: 2, to: Date())!
        let start = calendar.date(bySettingHour: 17, minute: 50, second: 0, of: day)!
        let end = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: day)!
        var now = start
        let config = FocusConfiguration(activeHours: .init(isEnabled: true, weekdays: Set(1...7), endMinute: 18 * 60, pausesTracking: true),
            focusDuration: 3600, microRemindersEnabled: false, pauseDuringMeetings: false,
            pauseWhileTyping: false, idleDetectionEnabled: false)
        store.save(configuration: config)
        let monitor = HoursForegroundMonitor()
        let controller = SessionController(store: store, now: start, foregroundAppMonitor: monitor, appUsageClock: { now })
        controller.start(at: now)
        defer { controller.stop(at: now) }
        now = end.addingTimeInterval(600)
        monitor.callback?(ForegroundApp(bundleID: "com.example.private", name: "Private"))
        #expect(monitor.callback == nil)
        #expect(store.loadAppUsageJournal().cursor == nil)
        controller.reconcile(at: now)
        let usage = controller.appUsage.segments(from: start, to: now, now: now)
        #expect(usage.allSatisfy { $0.endedAt <= end && $0.app.name == "Editor" })
        #expect(usage.reduce(0) { $0 + $1.endedAt.timeIntervalSince($1.startedAt) } == 600)
        let work = controller.activityIntervals(from: start, to: now, now: now).filter { $0.kind == .studying }
        #expect(work.reduce(0) { $0 + $1.endedAt.timeIntervalSince($1.startedAt) } == 600)
        #expect(work.allSatisfy { $0.endedAt <= end })
    }

    @Test func changingTheTrackingOptionWhileOutsideHoursStopsCollectionImmediately() throws {
        let suite = "ActiveHoursIntegrationTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SessionStore(defaults: defaults)
        let calendar = Calendar.current
        let day = calendar.date(byAdding: .day, value: 2, to: Date())!
        let start = calendar.date(bySettingHour: 19, minute: 0, second: 0, of: day)!
        var now = start
        var config = FocusConfiguration(activeHours: .init(isEnabled: true, weekdays: Set(1...7)),
            pauseDuringMeetings: false, pauseWhileTyping: false, idleDetectionEnabled: false)
        store.save(configuration: config)
        let controller = SessionController(store: store, now: start, foregroundAppMonitor: HoursForegroundMonitor(), appUsageClock: { now })
        controller.start(at: now)
        defer { controller.stop(at: now) }
        #expect(controller.activeStudyingStartedAt != nil)
        now = start.addingTimeInterval(60)
        config.activeHours.pausesTracking = true
        controller.updateConfiguration(config, at: now)
        #expect(controller.activeStudyingStartedAt == nil)
        #expect(store.loadAppUsageJournal().cursor == nil)
        #expect(store.loadConfiguration().activeHours.pausesTracking)
        now = start.addingTimeInterval(120)
        config.activeHours.isEnabled = false
        controller.updateConfiguration(config, at: now)
        #expect(controller.activeStudyingStartedAt == now)
        #expect(!controller.sessionSnapshot.status.isPaused)
    }
}

@MainActor
private final class HoursForegroundMonitor: ForegroundAppMonitoring {
    var callback: ((ForegroundApp?) -> Void)?
    func start(onChange: @escaping (ForegroundApp?) -> Void) {
        callback = onChange
        onChange(sample())
    }
    func stop() { callback = nil }
    func sample() -> ForegroundApp? { ForegroundApp(bundleID: "com.example.editor", name: "Editor") }
}
