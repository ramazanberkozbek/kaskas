import AppKit
import Foundation
import SwiftData
import Testing
@testable import Kaskas

@MainActor
struct CategoryDetectionTests {
    private let start = Date(timeIntervalSinceReferenceDate: 1_000_000)
    private let xcode = ForegroundApp(bundleID: "com.apple.dt.Xcode", name: "Xcode")
    private let safari = ForegroundApp(bundleID: "com.apple.Safari", name: "Safari")

    private func fixture() -> (SessionStore, CategoryRegistry, UserDefaults, String) {
        let suite = "CategoryDetectionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return (SessionStore(defaults: defaults), CategoryRegistry(defaults: defaults), defaults, suite)
    }

    private func segment(_ app: ForegroundApp, _ category: String, _ from: Double, _ to: Double) -> AppUsageSegment {
        AppUsageSegment(id: UUID(), app: app,
            resolution: CategoryResolution(categoryID: category, source: .userRule, ruleKey: app.bundleID),
            startedAt: start.addingTimeInterval(from), endedAt: start.addingTimeInterval(to))
    }

    @Test func exactUserRuleWinsWithoutSuffixOrDisplayNameMatching() {
        let (_, registry, defaults, suite) = fixture()
        defer { defaults.removePersistentDomain(forName: suite) }
        registry.addOrUpdateRule(appIdentifier: "org.unrelated.Xcode", displayName: "Z Tool", categoryId: "design")
        #expect(registry.resolveCategory(bundleId: "org.unrelated.Xcode", appName: "Z Tool").id == "design")
        #expect(registry.resolveCategory(bundleId: "org.another.Xcode", appName: "Xcode").id == "other")
        #expect(registry.resolveCategory(bundleId: " COM.APPLE.DT.XCODE ", appName: "Renamed").id == "coding")
        #expect(!CategoryRule(appIdentifier: "com.apple.dt.Xcode", displayName: "Xcode", categoryId: "coding")
            .matches(bundleId: "org.another.Xcode", appName: "Xcode"))
    }

    @Test func missingBundleUsesLegacyNamesButAmbiguityDoesNotGuess() {
        let (_, registry, defaults, suite) = fixture()
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(registry.resolution(bundleID: nil, appName: "Ghostty").categoryID == "coding")
        registry.addOrUpdateRule(appIdentifier: "one.app", displayName: "Tool", categoryId: "design")
        registry.addOrUpdateRule(appIdentifier: "two.app", displayName: "Tool", categoryId: "writing")
        #expect(registry.resolution(bundleID: nil, appName: "Tool").source == .ambiguous)
    }

    @Test func customRulesAndExplicitOtherSurviveReload() {
        let (_, registry, defaults, suite) = fixture()
        defer { defaults.removePersistentDomain(forName: suite) }
        registry.addOrUpdateRule(appIdentifier: xcode.bundleID!, displayName: "Xcode", categoryId: "design")
        let restored = CategoryRegistry(defaults: defaults)
        #expect(restored.resolution(bundleID: xcode.bundleID, appName: xcode.name).source == .userRule)
        #expect(restored.resolveCategory(bundleId: xcode.bundleID, appName: xcode.name).id == "design")
        restored.addOrUpdateRule(appIdentifier: xcode.bundleID!, displayName: "Xcode", categoryId: "other")
        #expect(restored.resolution(bundleID: xcode.bundleID, appName: xcode.name).source == .userRule)
        #expect(restored.resolveCategory(bundleId: xcode.bundleID, appName: xcode.name).id == "other")
    }

    @Test func deletingCategoryPreservesHistoricalMetadataAcrossReset() {
        let (_, registry, defaults, suite) = fixture()
        defer { defaults.removePersistentDomain(forName: suite) }
        let category = registry.addOrUpdateCategory(name: "Ders", iconName: "book", colorName: "blue")
        registry.removeCategory(id: category.id)
        registry.resetToDefaults()
        let restored = CategoryRegistry(defaults: defaults)
        #expect(restored.category(for: category.id) == nil)
        #expect(restored.historicalCategory(for: category.id)?.name == "Ders")
        restored.removeCategory(id: "other")
        #expect(restored.category(for: "other") != nil)
    }

    @Test func transitionsAndDuplicateEventsKeepStableIdentity() {
        let (store, registry, defaults, suite) = fixture()
        defer { defaults.removePersistentDomain(forName: suite) }
        let tracker = AppUsageTracker(sessionStore: store, usageStore: nil)
        let coding = registry.resolution(bundleID: xcode.bundleID, appName: xcode.name)
        tracker.update(app: xcode, resolution: coding, at: start)
        let id = tracker.journal.cursor?.id
        tracker.update(app: xcode, resolution: coding, at: start.addingTimeInterval(10))
        #expect(tracker.journal.cursor?.id == id)
        tracker.update(app: safari, resolution: registry.resolution(bundleID: safari.bundleID, appName: safari.name), at: start.addingTimeInterval(20))
        tracker.update(app: nil, at: start.addingTimeInterval(30))
        let records = tracker.segments(from: start, to: start.addingTimeInterval(40), now: start.addingTimeInterval(40))
        #expect(records.count == 2)
        #expect(records[0].id == id)
        #expect(records[0].endedAt == records[1].startedAt)
        #expect(records.map(\.resolution.categoryID) == ["coding", "browsing"])
    }

    @Test func crashRecoveryStopsAtCheckpointAndDoesNotFillClosedTime() {
        let (store, registry, defaults, suite) = fixture()
        defer { defaults.removePersistentDomain(forName: suite) }
        let tracker = AppUsageTracker(sessionStore: store, usageStore: nil)
        let resolution = registry.resolution(bundleID: xcode.bundleID, appName: xcode.name)
        tracker.update(app: xcode, resolution: resolution, at: start)
        tracker.update(app: xcode, resolution: resolution, at: start.addingTimeInterval(30))
        let restored = AppUsageTracker(sessionStore: store, usageStore: nil)
        #expect(restored.journal.cursor == nil)
        #expect(restored.journal.pending.count == 1)
        #expect(restored.journal.pending[0].endedAt == start.addingTimeInterval(30))
        restored.update(app: safari, at: start.addingTimeInterval(3600))
        #expect(restored.journal.cursor?.startedAt == start.addingTimeInterval(3600))
    }

    @Test func clockJumpClosesAtVerifiedCheckpoint() {
        let (store, _, defaults, suite) = fixture()
        defer { defaults.removePersistentDomain(forName: suite) }
        let tracker = AppUsageTracker(sessionStore: store, usageStore: nil)
        tracker.update(app: xcode, at: start)
        tracker.update(app: xcode, at: start.addingTimeInterval(30))
        tracker.clockDidChange()
        tracker.update(app: safari, at: start.addingTimeInterval(-3600))
        #expect(tracker.journal.pending[0].endedAt == start.addingTimeInterval(30))
        #expect(tracker.journal.cursor?.startedAt == start.addingTimeInterval(-3600))
    }

    @Test func disableStopsCollectionAndRejectsOldCallbacksAfterReenable() {
        let (store, registry, defaults, suite) = fixture()
        defer { defaults.removePersistentDomain(forName: suite) }
        let monitor = FakeForegroundMonitor(app: xcode)
        var time = start
        let controller = AppUsageController(sessionStore: store, registry: registry, usageStore: nil, monitor: monitor, clock: { time })
        #expect(controller.isEnabled)
        controller.setWorking(true, at: time)
        let stale = monitor.callback
        time = start.addingTimeInterval(10)
        controller.setEnabled(false, at: time)
        #expect(monitor.stops == 1)
        let samples = monitor.samples
        controller.setWorking(true, at: start.addingTimeInterval(20))
        registry.resetToDefaults()
        #expect(monitor.samples == samples)
        #expect(!store.automaticCategoryDetectionEnabled)
        time = start.addingTimeInterval(30)
        monitor.app = safari
        controller.setEnabled(true, at: time)
        stale?(xcode)
        time = start.addingTimeInterval(40)
        controller.setWorking(false, at: time)
        let records = controller.segments(from: start, to: time, now: time)
        #expect(records.count == 2)
        #expect(records[0].endedAt == start.addingTimeInterval(10))
        #expect(records[1].startedAt == start.addingTimeInterval(30))
        #expect(records[1].app == safari)
    }

    @Test func savedFalseNeverSamplesAndResetPreservesPreference() {
        let (store, registry, defaults, suite) = fixture()
        defer { defaults.removePersistentDomain(forName: suite) }
        store.automaticCategoryDetectionEnabled = false
        let monitor = FakeForegroundMonitor(app: xcode)
        let controller = AppUsageController(sessionStore: store, registry: registry, usageStore: nil, monitor: monitor)
        controller.setWorking(true, at: start)
        controller.clockDidChange(at: start)
        registry.resetToDefaults()
        #expect(!controller.isEnabled)
        #expect(monitor.starts == 0)
        #expect(monitor.samples == 0)
        #expect(!SessionStore(defaults: defaults).automaticCategoryDetectionEnabled)
    }

    @Test func liveRuleChangesSplitUsageButDoNotRewriteHistory() {
        let (store, registry, defaults, suite) = fixture()
        defer { defaults.removePersistentDomain(forName: suite) }
        var time = start
        let monitor = FakeForegroundMonitor(app: xcode)
        let controller = AppUsageController(sessionStore: store, registry: registry, usageStore: nil, monitor: monitor, clock: { time })
        controller.setWorking(true, at: time)
        time = start.addingTimeInterval(10)
        registry.addOrUpdateRule(appIdentifier: xcode.bundleID!, displayName: "Xcode", categoryId: "design")
        time = start.addingTimeInterval(20)
        controller.setWorking(false, at: time)
        let records = controller.segments(from: start, to: time, now: time)
        #expect(records.map(\.resolution.categoryID) == ["coding", "design"])
        #expect(monitor.starts == 1)
    }

    @Test func pausesStopMonitoringAndResumeWithFreshApp() {
        let (store, registry, defaults, suite) = fixture()
        defer { defaults.removePersistentDomain(forName: suite) }
        var time = start
        let monitor = FakeForegroundMonitor(app: xcode)
        let controller = AppUsageController(sessionStore: store, registry: registry, usageStore: nil, monitor: monitor, clock: { time })
        controller.setWorking(true, at: time)
        time = start.addingTimeInterval(10)
        controller.setWorking(false, at: time)
        monitor.app = safari
        time = start.addingTimeInterval(50)
        controller.setWorking(true, at: time)
        time = start.addingTimeInterval(60)
        controller.setWorking(false, at: time)
        let records = controller.segments(from: start, to: time, now: time)
        #expect(monitor.starts == 2)
        #expect(monitor.stops == 2)
        #expect(records.map(\.app) == [xcode, safari])
        #expect(records.reduce(0) { $0 + $1.endedAt.timeIntervalSince($1.startedAt) } == 20)
    }

    @Test func dayBoundaryUsesCalendarWindowIncludingDST() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))
        let day = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 1)))
        let nextDay = try #require(calendar.date(byAdding: .day, value: 1, to: day))
        #expect(nextDay.timeIntervalSince(day) == 25 * 3600)
        let began = day.addingTimeInterval(-30)
        let ended = nextDay.addingTimeInterval(30)
        let interval = ActivityInterval(kind: .studying, startedAt: began, endedAt: ended)
        let record = AppUsageSegment(id: UUID(), app: xcode, resolution: .unmatched, startedAt: began, endedAt: ended)
        let summary = CategoryUsageSummary.make(intervals: [interval], usage: [record], from: day, to: nextDay)
        #expect(summary.total == 25 * 3600)
        #expect(summary.entries.isEmpty)
        #expect(summary.undetected == summary.total)
        #expect(summary.undetectedApps.map(\.app) == [xcode])
        #expect(summary.undetectedApps.map(\.duration) == [summary.total])
        #expect(summary.unrecordedDuration == 0)
    }

    @Test func retrospectiveIdleAndOverlapsDoNotInflateStudyTotals() {
        let intervals = [ActivityInterval(kind: .studying, startedAt: start, endedAt: start.addingTimeInterval(40)),
            ActivityInterval(kind: .breakTime, startedAt: start.addingTimeInterval(40), endedAt: start.addingTimeInterval(80)),
            ActivityInterval(kind: .studying, startedAt: start.addingTimeInterval(80), endedAt: start.addingTimeInterval(100))]
        let coding = segment(xcode, "coding", 0, 60)
        let usage = [coding, coding, segment(safari, "browsing", 30, 90)]
        let summary = CategoryUsageSummary.make(intervals: intervals, usage: usage, from: start, to: start.addingTimeInterval(100))
        #expect(summary.total == 60)
        #expect(summary.entries.first { $0.categoryID == "coding" }?.duration == 40)
        #expect(summary.entries.first { $0.categoryID == "browsing" }?.duration == 10)
        #expect(summary.undetected == 10)
        #expect(summary.entries.reduce(0) { $0 + $1.duration } + summary.undetected == summary.total)
    }

    @Test func reportingWindowClipsAndMergesStudyRecords() {
        let interval = ActivityInterval(kind: .studying, startedAt: start, endedAt: start.addingTimeInterval(120))
        let summary = CategoryUsageSummary.make(intervals: [interval, interval], usage: [segment(xcode, "coding", 0, 120)],
            from: start.addingTimeInterval(30), to: start.addingTimeInterval(90))
        #expect(summary.total == 60)
        #expect(summary.entries[0].duration == 60)
        #expect(summary.undetected == 0)
    }

    @Test func zeroLengthSegmentsAreNotPersisted() {
        let (store, _, defaults, suite) = fixture()
        defer { defaults.removePersistentDomain(forName: suite) }
        let tracker = AppUsageTracker(sessionStore: store, usageStore: nil)
        tracker.update(app: xcode, at: start)
        tracker.update(app: nil, at: start)
        #expect(tracker.journal.pending.isEmpty)
    }

    @Test func failedWriteRetriesIdempotentlyWithoutLosingJournal() {
        let (store, _, defaults, suite) = fixture()
        defer { defaults.removePersistentDomain(forName: suite) }
        let database = FailingUsageStore()
        let tracker = AppUsageTracker(sessionStore: store, usageStore: database)
        tracker.update(app: xcode, at: start)
        database.shouldFail = true
        tracker.update(app: nil, at: start.addingTimeInterval(10))
        #expect(tracker.storageFailed)
        #expect(store.loadAppUsageJournal().pending.count == 1)
        database.shouldFail = false
        let records = tracker.segments(from: start, to: start.addingTimeInterval(20), now: start.addingTimeInterval(20))
        #expect(records.count == 1)
        #expect(!tracker.storageFailed)
        #expect(store.loadAppUsageJournal().pending.isEmpty)
        #expect(database.records.count == 1)
    }

    @Test func swiftDataInsertIsIdempotent() throws {
        let container = try ModelContainer(for: AppUsageRecord.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let store = AppUsageStore(container: container)
        let record = segment(xcode, "coding", 0, 10)
        try store.insert(record)
        try store.insert(record)
        #expect(try store.segments(from: start, to: start.addingTimeInterval(20)) == [record])
    }

    @Test func addingUsageModelPreservesExistingActivityDatabase() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("history.store")
        let activity = ActivityInterval(kind: .studying, startedAt: start, endedAt: start.addingTimeInterval(60))
        try autoreleasepool {
            let oldContainer = try ModelContainer(for: BreakRecord.self, ActivityRecord.self, configurations: ModelConfiguration(url: url))
            try ActivityStore(container: oldContainer).insert(activity)
        }
        let updated = try ModelContainer(for: BreakRecord.self, ActivityRecord.self, AppUsageRecord.self, configurations: ModelConfiguration(url: url))
        #expect(try ActivityStore(container: updated).intervals(from: start, to: start.addingTimeInterval(100)) == [activity])
        let usageStore = AppUsageStore(container: updated)
        let record = segment(xcode, "coding", 0, 60)
        try usageStore.insert(record)
        #expect(try usageStore.segments(from: start, to: start.addingTimeInterval(100)) == [record])
    }

    @Test func nativeMonitorObservesWorkspaceWithoutReadingWindowContent() {
        let monitor = ForegroundAppMonitor()
        var count = 0
        monitor.start { _ in count += 1 }
        #expect(count == 1)
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.activationPolicy == .regular }) {
            NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.didActivateApplicationNotification, object: NSWorkspace.shared,
                userInfo: [NSWorkspace.applicationUserInfoKey: app])
            #expect(count == 2)
        }
        monitor.stop()
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.screensDidSleepNotification, object: NSWorkspace.shared)
        #expect(count <= 2)
    }

    @Test func currentAppIsIdentifiedAsForegroundApp() {
        let monitor = ForegroundAppMonitor()
        var reportedApp: ForegroundApp?
        monitor.start { reportedApp = $0 }
        let current = NSRunningApplication.current
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.didActivateApplicationNotification, object: NSWorkspace.shared,
            userInfo: [NSWorkspace.applicationUserInfoKey: current])
        #expect(reportedApp != nil)
        #expect(reportedApp?.name == (current.localizedName ?? "Kaskas"))
        monitor.stop()
    }
}

@MainActor
private final class FakeForegroundMonitor: ForegroundAppMonitoring {
    var app: ForegroundApp?
    var callback: ((ForegroundApp?) -> Void)?
    var starts = 0
    var stops = 0
    var samples = 0
    init(app: ForegroundApp?) { self.app = app }
    func start(onChange: @escaping (ForegroundApp?) -> Void) { starts += 1; callback = onChange; onChange(sample()) }
    func stop() { stops += 1; callback = nil }
    func sample() -> ForegroundApp? { samples += 1; return app }
}

@MainActor
private final class FailingUsageStore: AppUsageRecording {
    enum Failure: Error { case write }
    var shouldFail = false
    var records: [UUID: AppUsageSegment] = [:]
    func insert(_ segment: AppUsageSegment) throws {
        if shouldFail { throw Failure.write }
        records[segment.id] = segment
    }
    func segments(from start: Date, to end: Date) throws -> [AppUsageSegment] {
        records.values.filter { $0.startedAt < end && $0.endedAt > start }
    }
}
