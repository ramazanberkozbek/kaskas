import Foundation
import Observation

/// Manages foreground application tracking and records usage during active focus sessions.
@MainActor
@Observable
final class AppUsageController {
    private(set) var isEnabled: Bool
    let exclusions: AppExclusionPreferences
    private(set) var storageFailed: Bool
    @ObservationIgnored private let sessionStore: SessionStore
    @ObservationIgnored private let registry: CategoryRegistry
    @ObservationIgnored private let tracker: AppUsageTracker
    @ObservationIgnored private let excludedTracker: ExcludedUsageTracker
    @ObservationIgnored private let monitor: any ForegroundAppMonitoring
    @ObservationIgnored private var isWorking = false
    @ObservationIgnored private var isMonitoring = false
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private let clock: () -> Date
    @ObservationIgnored private var currentApp: ForegroundApp?

    init(sessionStore: SessionStore, registry: CategoryRegistry, usageStore: (any AppUsageRecording)?,
         excludedUsageStore: (any ExcludedUsageRecording)? = nil,
         monitor: any ForegroundAppMonitoring = ForegroundAppMonitor(), clock: @escaping () -> Date = Date.init) {
        self.sessionStore = sessionStore
        self.registry = registry
        self.monitor = monitor
        self.clock = clock
        exclusions = sessionStore.appExclusions
        excludedTracker = ExcludedUsageTracker(sessionStore: sessionStore, usageStore: excludedUsageStore)
        isEnabled = sessionStore.automaticCategoryDetectionEnabled
        tracker = AppUsageTracker(sessionStore: sessionStore, usageStore: usageStore)
        storageFailed = tracker.storageFailed
        tracker.onStorageFailureChanged = { [weak self] _ in self?.refreshStorageFailure() }
        excludedTracker.onStorageFailureChanged = { [weak self] _ in self?.refreshStorageFailure() }
        registry.onChange = { [weak self] in self?.rulesChanged() }
        exclusions.onChange = { [weak self] in
            guard let self else { return }
            self.synchronize(at: self.clock())
        }
    }

    func setEnabled(_ enabled: Bool, at now: Date = Date()) {
        guard enabled != isEnabled else { return }
        isEnabled = enabled
        sessionStore.automaticCategoryDetectionEnabled = enabled
        synchronize(at: now)
    }

    func setWorking(_ working: Bool, at now: Date) {
        isWorking = working
        synchronize(at: now)
    }

    func clockDidChange(at now: Date) {
        tracker.clockDidChange()
        excludedTracker.clockDidChange()
        if isMonitoring { currentApp = monitor.sample(); record(at: now) }
        refreshStorageFailure()
    }

    func segments(from start: Date, to end: Date, now: Date) -> [AppUsageSegment] {
        let segments = tracker.segments(from: start, to: end, now: now)
        refreshStorageFailure()
        return Self.resolve(segments, using: registry.resolverSnapshot())
    }

    func segmentsAsync(from start: Date, to end: Date, now: Date) async -> [AppUsageSegment] {
        let segments = await tracker.segmentsAsync(from: start, to: end, now: now)
        refreshStorageFailure()
        return await Self.resolveAsync(segments, using: registry.resolverSnapshot())
    }

    /// Stored assignments describe collection time. Reports use today's rules for
    /// persisted, pending and live usage alike, without rewriting the history store.
    nonisolated private static func resolve(_ segments: [AppUsageSegment], using resolver: CategoryResolver) -> [AppUsageSegment] {
        segments.map { segment in
            AppUsageSegment(id: segment.id, app: segment.app,
                resolution: resolver.resolve(bundleID: segment.app.bundleID, appName: segment.app.name),
                startedAt: segment.startedAt, endedAt: segment.endedAt)
        }
    }

    @concurrent private static func resolveAsync(_ segments: [AppUsageSegment], using resolver: CategoryResolver) async -> [AppUsageSegment] {
        resolve(segments, using: resolver)
    }

    func suspendPersistence() { tracker.suspendPersistence(); excludedTracker.suspendPersistence() }
    func resumePersistence() { tracker.resumePersistence(); excludedTracker.resumePersistence() }
    func waitForPersistence() async {
        await tracker.waitForPersistence()
        await excludedTracker.waitForPersistence()
    }
    func resetHistory(at now: Date) { tracker.resetHistory(at: now); excludedTracker.resetHistory(at: now) }

    private func synchronize(at now: Date) {
        let shouldMonitor = isWorking && (isEnabled || !exclusions.applications.isEmpty)
        if shouldMonitor && !isMonitoring {
            isMonitoring = true
            generation += 1
            let activeGeneration = generation
            // Initial sampling occurs only when category recording or exclusions need it.
            monitor.start { [weak self] app in
                guard let self, self.isWorking, self.isMonitoring, self.generation == activeGeneration else { return }
                self.currentApp = app
                self.record(at: self.clock())
            }
        } else if !shouldMonitor && isMonitoring {
            isMonitoring = false
            generation += 1
            monitor.stop()
            currentApp = nil
            record(at: now)
        } else if shouldMonitor {
            record(at: now)
        }
        refreshStorageFailure()
    }

    private func rulesChanged() {
        guard isMonitoring else { return }
        record(at: clock())
    }

    func excludedIntervals(from start: Date, to end: Date, now: Date) -> [ExcludedUsageInterval] {
        let values = excludedTracker.intervals(from: start, to: end, now: now)
        refreshStorageFailure()
        return values
    }

    func excludedIntervalsAsync(from start: Date, to end: Date, now: Date) async -> [ExcludedUsageInterval] {
        let values = await excludedTracker.intervalsAsync(from: start, to: end, now: now)
        refreshStorageFailure()
        return values
    }

    private func refreshStorageFailure() {
        storageFailed = tracker.storageFailed || excludedTracker.storageFailed
    }

    private func record(at now: Date) {
        let isExcluded = isMonitoring && currentApp.map { exclusions.snapshot().contains($0) } == true
        let recordedApp = isMonitoring && isEnabled && !isExcluded ? currentApp : nil
        let resolution = registry.resolution(bundleID: recordedApp?.bundleID, appName: recordedApp?.name)
        tracker.update(app: recordedApp, resolution: resolution, at: now)
        excludedTracker.update(isExcluded: isExcluded, at: now)
        refreshStorageFailure()
    }
}
