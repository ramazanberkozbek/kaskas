import Foundation
import Observation

/// Manages foreground application tracking and records usage during active focus sessions.
@MainActor
@Observable
final class AppUsageController {
    private(set) var isEnabled: Bool
    private(set) var storageFailed: Bool
    @ObservationIgnored private let sessionStore: SessionStore
    @ObservationIgnored private let registry: CategoryRegistry
    @ObservationIgnored private let tracker: AppUsageTracker
    @ObservationIgnored private let monitor: any ForegroundAppMonitoring
    @ObservationIgnored private var isWorking = false
    @ObservationIgnored private var isMonitoring = false
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private let clock: () -> Date
    @ObservationIgnored private var currentApp: ForegroundApp?

    init(sessionStore: SessionStore, registry: CategoryRegistry, usageStore: (any AppUsageRecording)?,
         monitor: any ForegroundAppMonitoring = ForegroundAppMonitor(), clock: @escaping () -> Date = Date.init) {
        self.sessionStore = sessionStore
        self.registry = registry
        self.monitor = monitor
        self.clock = clock
        isEnabled = sessionStore.automaticCategoryDetectionEnabled
        tracker = AppUsageTracker(sessionStore: sessionStore, usageStore: usageStore)
        storageFailed = tracker.storageFailed
        registry.onChange = { [weak self] in self?.rulesChanged() }
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
        if isMonitoring { currentApp = monitor.sample(); record(at: now) }
        storageFailed = tracker.storageFailed
    }

    func segments(from start: Date, to end: Date, now: Date) -> [AppUsageSegment] {
        let segments = tracker.segments(from: start, to: end, now: now)
        storageFailed = tracker.storageFailed
        return segments
    }

    func segmentsAsync(from start: Date, to end: Date, now: Date) async -> [AppUsageSegment] {
        let segments = await tracker.segmentsAsync(from: start, to: end, now: now)
        storageFailed = tracker.storageFailed
        return segments
    }

    private func synchronize(at now: Date) {
        let shouldMonitor = isEnabled && isWorking
        if shouldMonitor && !isMonitoring {
            isMonitoring = true
            generation += 1
            let activeGeneration = generation
            // Initial sampling belongs to the monitor; it occurs only while enabled.
            monitor.start { [weak self] app in
                guard let self, self.isEnabled, self.isWorking, self.isMonitoring, self.generation == activeGeneration else { return }
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
        storageFailed = tracker.storageFailed
    }

    private func rulesChanged() {
        guard isMonitoring else { return }
        record(at: clock())
    }

    private func record(at now: Date) {
        let resolution = registry.resolution(bundleID: currentApp?.bundleID, appName: currentApp?.name)
        tracker.update(app: currentApp, resolution: resolution, at: now)
        storageFailed = tracker.storageFailed
    }
}
