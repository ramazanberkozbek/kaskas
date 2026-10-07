import AppKit
import Foundation
import Observation
import SwiftUI

/// Coordinates session state, monitoring, presentation, and persistence.
@MainActor
@Observable
final class SessionController {
    private(set) var configuration: FocusConfiguration
    private(set) var sessionSnapshot: SessionSnapshot
    private(set) var historySaveFailed = false
    private(set) var activityStorageFailed = false
    private(set) var annotationsRevision = 0
    private(set) var historyRevision = 0
    private(set) var isDeletingHistory = false
    private(set) var speedMultiplier: Double = 1.0
    @ObservationIgnored private var speedTimer: Timer?
    let appUsage: AppUsageController
    let categoryRegistry: CategoryRegistry
    let launchAtLogin = LaunchAtLoginController()

    var locale: Locale {
        configuration.appLanguage.locale
    }

    private var systemThemeRevision = 0

    var effectiveColorScheme: ColorScheme {
        _ = systemThemeRevision
        return configuration.appAppearance.effectiveColorScheme
    }

    func systemThemeDidChange() {
        guard configuration.appAppearance == .system else { return }
        systemThemeRevision += 1
        applyAppearance()
    }

    var targetSettingsPane: SettingsPane?
    var targetSettingsSection: String?

    @ObservationIgnored private var engine: SessionEngine
    @ObservationIgnored private let scheduler: SessionScheduler
    @ObservationIgnored private let customWallpaperStore: CustomWallpaperStore
    @ObservationIgnored private let store: SessionStore
    @ObservationIgnored private let persistence: SessionPersistence
    @ObservationIgnored private let activityTracker: ActivityTracker
    @ObservationIgnored private let breakHistoryStore: BreakHistoryStore?
    @ObservationIgnored private let microReminderPresenter: MicroReminderPresenter
    @ObservationIgnored private let breakWarningPresenter: BreakWarningPresenter
    @ObservationIgnored private let breakPresenter: BreakPresenter
    @ObservationIgnored private let settingsPresenter: SettingsPresenter
    @ObservationIgnored private let skippedBreakNotifier = SkippedBreakNotifier()
    @ObservationIgnored private let idleBreakNotifier = IdleBreakNotifier()
    @ObservationIgnored private let typingMonitor: any TypingActivityMonitoring
    @ObservationIgnored private let meetingPauseIndicator = CursorBreakCountdownPresenter()
    @ObservationIgnored private var lastProtectionIndicatorAt: Date?
    @ObservationIgnored private let cursorIdleMonitor = CursorIdleMonitor()
    @ObservationIgnored private let meetingMonitor: any MeetingActivityMonitoring
    @ObservationIgnored private let videoMonitor: any VideoActivityMonitoring
    @ObservationIgnored private var checkpointTimer: Timer?
    @ObservationIgnored private var hasStarted = false
    @ObservationIgnored private var trackingWindowEnd: Date?
    private var cachedTodayBaseStudyingTime: TimeInterval = 0
    private var cachedTodayStartOfDay: Date?
    @ObservationIgnored private var screenTimeRefreshTask: Task<Void, Never>?
    @ObservationIgnored private var screenTimeRefreshKey: ScreenTimeRefreshKey?

    private struct ScreenTimeRefreshKey: Equatable {
        let day: Date
        let completedRevision: Int
    }

    /// Called by lifecycle events and the menu clock, never by a render-time read.
    /// A checkpoint only moves the active cursor's endpoint, so it reuses the cache.
    func refreshScreenTimeToday(at now: Date = Date()) {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: now)
        let key = ScreenTimeRefreshKey(day: day, completedRevision: activityTracker.completedIntervalsRevision)
        guard screenTimeRefreshKey != key else { return }
        screenTimeRefreshKey = key
        screenTimeRefreshTask?.cancel()
        let tracker = activityTracker
        screenTimeRefreshTask = Task { [weak self] in
            let intervals = await tracker.intervalsAsync(from: day, to: now, now: now, includeActiveCursor: false)
            guard !Task.isCancelled else { return }
            let total = await Self.completedStudyingTime(intervals: intervals, day: day, calendar: calendar)
            guard !Task.isCancelled, let self, self.screenTimeRefreshKey == key else { return }
            self.cachedTodayBaseStudyingTime = total
            self.cachedTodayStartOfDay = day
            self.screenTimeRefreshTask = nil
        }
    }

    @concurrent private static func completedStudyingTime(
        intervals: [ActivityInterval], day: Date, calendar: Calendar
    ) async -> TimeInterval {
        ActivityStatistics.days(from: day, through: day, intervals: intervals, calendar: calendar).first?.studying ?? 0
    }

    /// Allows deterministic validation without moving any work into the getter.
    func waitForScreenTimeRefresh() async {
        await screenTimeRefreshTask?.value
    }

    deinit {
        screenTimeRefreshTask?.cancel()
    }

    init(
        store: SessionStore = SessionStore(),
        customWallpaperStore: CustomWallpaperStore = .shared,
        historyStore: (any BreakHistoryRecording)? = nil,
        activityStore: (any ActivityRecording)? = nil,
        appUsageStore: (any AppUsageRecording)? = nil,
        excludedUsageStore: (any ExcludedUsageRecording)? = nil,
        categoryRegistry: CategoryRegistry = CategoryRegistry(),
        scheduler: SessionScheduler = SessionScheduler(),
        microReminderPresenter: MicroReminderPresenter = MicroReminderPresenter(),
        breakWarningPresenter: BreakWarningPresenter = BreakWarningPresenter(),
        breakPresenter: BreakPresenter = BreakPresenter(),
        settingsPresenter: SettingsPresenter = SettingsPresenter(),
        meetingMonitor: any MeetingActivityMonitoring = MeetingActivityMonitor(),
        videoMonitor: any VideoActivityMonitoring = VideoActivityMonitor(),
        typingMonitor: any TypingActivityMonitoring = TypingActivityMonitor(),
        now: Date = Date(),
        foregroundAppMonitor: any ForegroundAppMonitoring = ForegroundAppMonitor(),
        appUsageClock: @escaping () -> Date = Date.init
    ) {
        let configuration = store.loadConfiguration()
        self.configuration = configuration
        AppLanguage.currentLocale = configuration.appLanguage.locale
        if UserDefaults.standard.array(forKey: "AppleLanguages") == nil, configuration.appLanguage != .system {
            UserDefaults.standard.set([configuration.appLanguage.rawValue], forKey: "AppleLanguages")
        }
        self.store = store
        self.customWallpaperStore = customWallpaperStore
        self.meetingMonitor = meetingMonitor
        self.videoMonitor = videoMonitor
        self.typingMonitor = typingMonitor
        self.categoryRegistry = categoryRegistry
        appUsage = AppUsageController(sessionStore: store, registry: categoryRegistry, usageStore: appUsageStore, excludedUsageStore: excludedUsageStore, monitor: foregroundAppMonitor, clock: appUsageClock)
        persistence = SessionPersistence(store: store, historyStore: historyStore)
        activityTracker = ActivityTracker(sessionStore: store, activityStore: activityStore)
        breakHistoryStore = historyStore as? BreakHistoryStore
        historySaveFailed = historyStore == nil
        activityStorageFailed = activityStore == nil
        self.scheduler = scheduler
        self.microReminderPresenter = microReminderPresenter
        self.breakWarningPresenter = breakWarningPresenter
        self.breakPresenter = breakPresenter
        self.settingsPresenter = settingsPresenter

        let engine: SessionEngine
        if let restoredState = store.loadSessionState() {
            engine = SessionEngine(
                configuration: configuration,
                restoredState: restoredState,
                lastActiveAt: store.loadLastActiveAt(),
                now: now
            )
        } else {
            engine = SessionEngine(configuration: configuration, now: now)
        }
        self.engine = engine
        sessionSnapshot = engine.snapshot(at: now)
        activityTracker.onStorageFailureChanged = { [weak self] failed in
            self?.activityStorageFailed = failed
        }
        persistence.onHistoryFailureChanged = { [weak self] failed in
            self?.historySaveFailed = failed
        }
        refreshScreenTimeToday(at: now)
    }

    func start(at now: Date = Date()) {
        guard !hasStarted else {
            return
        }

        hasStarted = true
        configureMeetingMonitor()
        startVideoMonitoringIfNeeded()
        if configuration.pauseDuringMeetings {
            meetingMonitor.start { [weak self] active in
                guard let self else { return }
                MainActor.assumeIsolated {
                    self.handleMeetingActivity(active)
                }
            }
        }
        let meetingActive = configuration.pauseDuringMeetings && meetingMonitor.sample()
        let effects = engine.send(.launch(meetingActive: meetingActive, videoActive: configuration.pauseDuringVideo && videoMonitor.sample()), at: now)
        activityTracker.resume(as: currentActivityKind(at: now), at: now, preservingBreak: engine.status.isAwaitingReturn)
        trackingWindowEnd = configuration.activeHours.pausesTracking ? engine.activeHoursState?.window?.end : nil
        appUsage.setWorking(currentActivityKind(at: now) == .studying, at: now, until: trackingWindowEnd)
        apply(effects, at: now)
        startIdleMonitoringIfNeeded()
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.persistSession() }
        }
        RunLoop.main.add(timer, forMode: .common)
        checkpointTimer = timer
    }

    func stop(at now: Date = Date()) {
        wallpaperImportID = nil
        stopIdleMonitoring(at: now)
        checkpointTimer?.invalidate()
        checkpointTimer = nil
        meetingMonitor.stop()
        videoMonitor.stop()
        settingsPresenter.dismiss()
        appUsage.setWorking(false, at: now)
        hasStarted = false
        let effects = engine.send(.quit, at: now)
        apply(effects, at: now)
    }

    func systemWillSleep(at now: Date = Date()) {
        stopIdleMonitoring(at: now, preservingIdleState: true)
        let effects = engine.send(.sleep, at: now)
        apply(effects, at: now)
    }

    func systemDidWake(at now: Date = Date()) {
        let meetingActive = configuration.pauseDuringMeetings && meetingMonitor.sample()
        let effects = engine.send(.systemResumed(meetingActive: meetingActive, videoActive: configuration.pauseDuringVideo && videoMonitor.sample()), at: now)
        apply(effects, at: now)
        startIdleMonitoringIfNeeded()
    }

    func screenOrSessionDidLock(at now: Date = Date()) {
        stopIdleMonitoring(at: now, preservingIdleState: true)
        let effects = engine.send(.lock, at: now)
        apply(effects, at: now)
    }

    func screenOrSessionDidUnlock(at now: Date = Date()) {
        let meetingActive = configuration.pauseDuringMeetings && meetingMonitor.sample()
        let effects = engine.send(.systemResumed(meetingActive: meetingActive, videoActive: configuration.pauseDuringVideo && videoMonitor.sample()), at: now)
        apply(effects, at: now)
        startIdleMonitoringIfNeeded()
    }

    func reconcile(at now: Date = Date(), showsBreakWarning: Bool = true) {
        cursorIdleMonitor.sample(
            threshold: configuration.idleDetectionEnabled ? configuration.idleThreshold : .infinity,
            at: now
        )
        refreshProtection(at: now, showsBreakWarning: showsBreakWarning)
        refreshTyping(active: typingMonitor.sample(), at: now, showsBreakWarning: showsBreakWarning)
        let effects = engine.send(.tick, at: now)
        apply(effects, at: now, showsBreakWarning: showsBreakWarning)
    }

    func snapshot(at now: Date = Date()) -> SessionSnapshot {
        engine.snapshot(at: now)
    }

    func breaksTakenToday(at now: Date = Date()) -> Int {
        engine.breaksTakenToday(at: now)
    }

    func screenTimeToday(at now: Date = Date()) -> TimeInterval {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: now)

        let base = cachedTodayStartOfDay == startOfDay ? cachedTodayBaseStudyingTime : 0
        if let startedAt = activeStudyingStartedAt {
            let effectiveStart = max(startOfDay, startedAt)
            let effectiveEnd = min(now, trackingWindowEnd ?? now)
            return base + max(0, effectiveEnd.timeIntervalSince(effectiveStart))
        }
        return base
    }

    func activityIntervals(from start: Date, to end: Date, now: Date = Date()) -> [ActivityInterval] {
        let intervals = activityTracker.intervals(from: start, to: end, now: now)
        if activityStorageFailed != activityTracker.storageFailed {
            activityStorageFailed = activityTracker.storageFailed
        }
        return intervals
    }

    func activityIntervalsAsync(from start: Date, to end: Date, now: Date) async -> [ActivityInterval] {
        let intervals = await activityTracker.intervalsAsync(from: start, to: end, now: now)
        if activityStorageFailed != activityTracker.storageFailed {
            activityStorageFailed = activityTracker.storageFailed
        }
        return intervals
    }

    func breakEntriesAsync(from start: Date, through end: Date) async -> [BreakHistoryEntry] {
        let upperBound = end.addingTimeInterval(0.001)
        let buffered = persistence.bufferedHistoryEntries
        let persisted = (try? await breakHistoryStore?.entriesAsync(from: start, to: upperBound)) ?? []
        guard !Task.isCancelled else { return [] }
        return await SessionPersistence.mergeEntriesAsync(persisted, buffered: buffered, from: start, to: upperBound)
    }

    func annotation(for interval: ActivityInterval) -> SessionAnnotation {
        store.annotation(for: interval)
    }

    func save(annotation: SessionAnnotation, for interval: ActivityInterval) {
        store.save(annotation: annotation, for: interval)
        annotationsRevision += 1
    }

    var activeStudyingStartedAt: Date? {
        guard let cursor = activityTracker.journal.cursor, cursor.kind == .studying else { return nil }
        return cursor.startedAt
    }

    func annotation(for session: StudySession) -> SessionAnnotation {
        store.annotation(for: session)
    }

    func save(annotation: SessionAnnotation, for session: StudySession) {
        store.save(annotation: annotation, for: session)
        annotationsRevision += 1
    }

    func save(categorySelection: SessionCategorySelection, note: String, for session: StudySession) {
        let categoryName: String?
        if case .category(let id) = categorySelection {
            categoryName = categoryRegistry.historicalCategory(for: id)?.name
        } else {
            categoryName = nil
        }
        store.save(categorySelection: categorySelection, categoryName: categoryName, note: note, for: session)
        annotationsRevision += 1
    }

    func breakEntries(from start: Date, through end: Date) -> [BreakHistoryEntry] {
        let upperBound = end.addingTimeInterval(0.001)
        let persisted = (try? breakHistoryStore?.entries(from: start, to: upperBound)) ?? []
        return SessionPersistence.mergeEntries(persisted, buffered: persistence.bufferedHistoryEntries,
            from: start, to: upperBound)
    }

    func applyDockVisibility() {
        settingsPresenter.setDockVisibility(configuration.showInDock)
    }

    func applyAppearance() {
        NSApplication.shared.appearance = configuration.appAppearance.nsAppearance
    }

    func updateConfiguration(_ configuration: FocusConfiguration, at now: Date = Date()) {
        let idleSettingsChanged = configuration.idleDetectionEnabled != self.configuration.idleDetectionEnabled
            || configuration.idleThreshold != self.configuration.idleThreshold
        let warningSettingsChanged = configuration.breakWarningEnabled != self.configuration.breakWarningEnabled
            || configuration.breakWarningLeadTime != self.configuration.breakWarningLeadTime
            || configuration.notificationPosition != self.configuration.notificationPosition
        if idleSettingsChanged { stopIdleMonitoring(at: now) }
        if warningSettingsChanged {
            breakWarningPresenter.dismiss()
        }
        if configuration.appLanguage != self.configuration.appLanguage {
            switch configuration.appLanguage {
            case .system:
                UserDefaults.standard.removeObject(forKey: "AppleLanguages")
            case .english:
                UserDefaults.standard.set(["en"], forKey: "AppleLanguages")
            case .turkish:
                UserDefaults.standard.set(["tr"], forKey: "AppleLanguages")
            }
            AppLanguage.currentLocale = configuration.appLanguage.locale
        }
        let meetingDetectionEnabled = configuration.pauseDuringMeetings && !self.configuration.pauseDuringMeetings
        let videoSettingsChanged = configuration.pauseDuringVideo != self.configuration.pauseDuringVideo
            || configuration.videoExcludedBundleIDs != self.configuration.videoExcludedBundleIDs
        let dockVisibilityChanged = configuration.showInDock != self.configuration.showInDock
        let appearanceChanged = configuration.appAppearance != self.configuration.appAppearance
        if configuration.breakBackground != self.configuration.breakBackground
            || configuration.customWallpaperPath != self.configuration.customWallpaperPath {
            wallpaperImportID = nil
        }
        self.configuration = configuration
        if dockVisibilityChanged { applyDockVisibility() }
        if appearanceChanged { applyAppearance() }
        configureMeetingMonitor()
        if videoSettingsChanged { startVideoMonitoringIfNeeded() }
        if !configuration.pauseDuringMeetings {
            meetingMonitor.stop()
        } else if !self.engine.configuration.pauseDuringMeetings {
            meetingMonitor.start { [weak self] active in
                guard let self else { return }
                MainActor.assumeIsolated { self.handleMeetingActivity(active) }
            }
        }
        let effects = engine.send(.updateConfiguration(configuration), at: now)
        store.save(configuration: configuration)
        apply(effects, at: now, showsBreakWarning: !warningSettingsChanged)
        if meetingDetectionEnabled || videoSettingsChanged || engine.status.isProtectionPaused {
            refreshProtection(at: now)
        }
        if idleSettingsChanged { startIdleMonitoringIfNeeded() }
        if engine.status.isTypingPaused {
            apply([.showBreakWarning(endsAt: engine.session.endsAt)], at: now)
        }
        if warningSettingsChanged,
           engine.status.phase == .focusing,
           engine.hasShownBreakWarning {
            breakWarningPresenter.suppress(endsAt: engine.session.endsAt)
        }
    }

    @ObservationIgnored private var wallpaperImportID: UUID?

    /// Activates a custom wallpaper only after background copying and image validation succeed.
    func setCustomWallpaper(from sourceURL: URL) async throws {
        let requestID = UUID()
        wallpaperImportID = requestID
        let wallpaperStore = customWallpaperStore
        let imported = try await wallpaperStore.save(from: sourceURL, preservingPath: configuration.customWallpaperPath)
        let revision = CustomWallpaperImages.shared.revision + 1
        await CustomWallpaperImageWorker.shared.prepareImportedThumbnail(imported, revision: revision)
        let targetURL = imported.url
        guard !Task.isCancelled, wallpaperImportID == requestID else {
            await wallpaperStore.removeOwnedFile(at: targetURL)
            throw CancellationError()
        }
        var config = configuration
        config.customWallpaperPath = targetURL.path
        config.breakBackground = .custom
        CustomWallpaperImages.shared.didImport()
        updateConfiguration(config)
    }

    func startBreakNow() {
        let effects = engine.send(.startBreakNow, at: Date())
        apply(effects)
    }

    func snooze() {
        let effects = engine.send(.snooze, at: Date())
        apply(effects)
    }

    func snoozeBreak() {
        let effects = engine.send(.snoozeBreak, at: Date())
        apply(effects)
    }

    func openSettings(pane: SettingsPane = .dashboard) {
        breakPresenter.dismiss()
        settingsPresenter.show(controller: self, pane: pane)
    }

    func openActiveHoursSettings() {
        targetSettingsSection = "activeHours"
        openSettings(pane: .focus)
    }

    func toggleManualPause() {
        let effects = engine.send(.toggleManualPause, at: Date())
        apply(effects)
    }

    func previewBreak() {
        breakPresenter.show(
            endsAt: Date.now.addingTimeInterval(20),
            configuration: configuration,
            isPreview: true,
            onSnooze: { [weak self] in
                self?.breakPresenter.dismissPreview()
            },
            onSkip: { [weak self] in
                self?.breakPresenter.dismissPreview()
            },
            onLockScreen: {
                SystemAction.lockScreen()
            },
            onOpenSettings: { [weak self] in
                self?.openSettings()
            }
        )
    }

    func previewMicroReminder() {
        guard configuration.microRemindersEnabled else { return }
        microReminderPresenter.show(
            displayMode: configuration.microReminderDisplayMode,
            mascot: configuration.microReminderMascot,
            color: configuration.microReminderColor,
            commitmentMode: configuration.microReminderCommitmentMode,
            isPreview: true
        )
    }

    func previewBreakWarning() {
        breakWarningPresenter.show(
            endsAt: Date.now.addingTimeInterval(configuration.breakWarningLeadTime),
            leadTime: configuration.breakWarningLeadTime,
            position: configuration.notificationPosition,
            isPreview: true,
            onStart: { [weak self] in
                self?.breakWarningPresenter.dismissPreview()
                self?.previewBreak()
            },
            onPostpone: { [weak self] _ in
                self?.breakWarningPresenter.dismissPreview()
            },
            onSkip: { [weak self] in
                self?.breakWarningPresenter.dismissPreview()
            }
        )
    }

    func previewSkippedBreakReminder() {
        skippedBreakNotifier.show(onStart: { [weak self] in self?.previewBreak() })
    }

    func previewIdleBreak() {
        idleBreakNotifier.show(
            duration: 300,
            onAccept: { [weak self] in
                self?.idleBreakNotifier.dismiss()
                self?.previewBreak()
            },
            onDecline: { [weak self] in
                self?.idleBreakNotifier.dismiss()
            }
        )
    }

    func dismissPreviews() {
        microReminderPresenter.dismissPreview()
        breakWarningPresenter.dismissPreview()
        breakPresenter.dismissPreview()
        skippedBreakNotifier.dismiss()
        idleBreakNotifier.dismiss()
    }

    // MARK: - Simulation & Time Machine

    func setSpeedMultiplier(_ multiplier: Double) {
        speedMultiplier = multiplier
        speedTimer?.invalidate()
        speedTimer = nil

        guard multiplier > 1.0 else { return }

        speedTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let extra = 0.5 * (multiplier - 1.0)
                self.advanceSession(by: extra)
            }
        }
    }

    func advanceSession(by seconds: TimeInterval) {
        engine.advanceTime(by: seconds)
        reconcile()
        refreshSnapshot()
    }

    func advanceDay() {
        engine.advanceDay(at: Date())
        reconcile()
        refreshSnapshot()
    }

    func deleteHistory() async throws {
        guard !isDeletingHistory else { return }
        guard let breakHistoryStore else { throw CocoaError(.fileNoSuchFile) }
        isDeletingHistory = true
        persistence.suspendPersistence()
        activityTracker.suspendPersistence()
        appUsage.suspendPersistence()
        defer {
            persistence.resumePersistence()
            activityTracker.resumePersistence()
            appUsage.resumePersistence()
            isDeletingHistory = false
        }
        await persistence.waitForPersistence()
        await activityTracker.waitForPersistence()
        await appUsage.waitForPersistence()
        try await breakHistoryStore.deleteAllHistory()

        let now = Date()
        persistence.resetHistory()
        activityTracker.resetHistory(at: now)
        appUsage.resetHistory(at: now)
        store.clearAnnotations()
        // Start a new cycle so a later completed break cannot restore pre-deletion focus time.
        dismissPreviews()
        microReminderPresenter.dismiss()
        breakWarningPresenter.dismiss()
        breakPresenter.dismiss()
        setSpeedMultiplier(1.0)
        engine = SessionEngine(configuration: configuration, now: now)
        reconcile(at: now)
        persistSession(at: now)
        refreshSnapshot(at: now)
        annotationsRevision += 1
        historyRevision += 1
        screenTimeRefreshTask?.cancel()
        screenTimeRefreshKey = nil
        cachedTodayBaseStudyingTime = 0
        cachedTodayStartOfDay = Calendar.current.startOfDay(for: now)
        refreshScreenTimeToday(at: now)
    }

    func resetSessionCycle() {
        setSpeedMultiplier(1.0)
        engine.resetFocus(at: Date())
        reconcile()
        refreshSnapshot()
    }


    func skipCurrentBreak() {
        let effects = engine.send(.skipBreak, at: Date())
        apply(effects)
    }

    func completeBreak() {
        let effects = engine.send(.completeBreak, at: Date())
        apply(effects)
    }

    private func skipUpcomingBreak() {
        let effects = engine.send(.skipBreak, at: Date())
        apply(effects)
    }

    private func postponeBreak(by duration: TimeInterval) {
        let effects = engine.send(.postponeBreak(by: duration), at: Date())
        apply(effects)
    }

    private func handleMeetingActivity(_ active: Bool) {
        guard hasStarted, configuration.pauseDuringMeetings else { return }
        refreshProtection()
    }

    func availableMeetingDevices() async -> [MeetingInputDevice] {
        await meetingMonitor.availableDevices()
    }

    private func configureMeetingMonitor() {
        meetingMonitor.configure(MeetingDetectionOptions(
            cameraEnabled: configuration.meetingCameraDetectionEnabled,
            virtualMicrophonesEnabled: configuration.meetingVirtualMicrophonesEnabled,
            excludedBundleIDs: configuration.meetingExcludedBundleIDs,
            excludedDeviceUIDs: configuration.meetingExcludedDeviceUIDs
        ))
    }

    private func startVideoMonitoringIfNeeded() {
        videoMonitor.stop()
        guard configuration.pauseDuringVideo else { return }
        videoMonitor.start(excludedBundleIDs: configuration.videoExcludedBundleIDs) { [weak self] _ in
            guard let self, self.hasStarted, self.configuration.pauseDuringVideo else { return }
            self.refreshProtection()
        }
    }

    func ignoreAutomaticPauseForCurrentCycle() {
        apply(engine.send(.ignoreProtectionForCycle, at: Date()))
    }

    private func refreshProtection(at now: Date = Date(), showsBreakWarning: Bool = true) {
        let effects = engine.send(.setProtection(
            meetingActive: configuration.pauseDuringMeetings && meetingMonitor.sample(),
            videoActive: configuration.pauseDuringVideo && videoMonitor.sample()
        ), at: now)
        apply(effects, at: now, showsBreakWarning: showsBreakWarning)
    }

    private func playBreakStartSound() {
        guard configuration.breakSoundEnabled else { return }
        BreakSoundPlayer.play(configuration.breakSound)
    }

    private func playBreakEndSound() {
        guard configuration.breakEndSoundEnabled else { return }
        BreakSoundPlayer.play(configuration.breakEndSound)
    }

    private func currentActivityKind(at now: Date) -> ActivityKind {
        if engine.status.isSystemPaused {
            return activityTracker.journal.cursor?.kind ?? .computerInactive
        }
        return engine.currentActivityKind(at: now)
    }

    private func startIdleMonitoringIfNeeded() {
        cursorIdleMonitor.shouldDetectIdle = { [weak self] in
            self?.engine.status.isProtectionPaused != true
        }
        cursorIdleMonitor.onActivity = { [weak self] now in
            guard let self, self.engine.status.isAwaitingReturn else { return }
            self.refreshProtection(at: now)
            self.apply(self.engine.send(.userActivity, at: now), at: now)
        }
        cursorIdleMonitor.onIdle = { [weak self] startedAt in
            self?.beginIdleBreak(at: startedAt)
        }
        cursorIdleMonitor.onReturn = { [weak self] _, returnedAt in
            self?.presentIdleBreak(returnedAt: returnedAt)
        }
        // Keep detecting post-break user activity even when idle detection is off.
        // An infinite threshold disables only the transition into idle.
        cursorIdleMonitor.start(threshold: configuration.idleDetectionEnabled ? configuration.idleThreshold : .infinity)
    }

    private func stopIdleMonitoring(at now: Date, preservingIdleState: Bool = false) {
        cursorIdleMonitor.stop()
        idleBreakNotifier.dismiss()
        if !preservingIdleState, engine.status.isIdlePaused {
            let effects = engine.send(.resolveIdle(acceptedAsBreak: false, returnedAt: now), at: now)
            apply(effects, at: now)
        }
    }

    private func beginIdleBreak(at startedAt: Date) {
        let effects = engine.send(.beginIdle(startedAt: startedAt), at: startedAt)
        apply(effects, at: startedAt)
    }

    private func presentIdleBreak(returnedAt: Date) {
        let effects = engine.send(.idleReturned(returnedAt: returnedAt), at: returnedAt)
        apply(effects, at: returnedAt)
    }

    private func resolveIdleBreak(accepted: Bool, returnedAt: Date) {
        let effects = engine.send(.resolveIdle(acceptedAsBreak: accepted, returnedAt: returnedAt), at: returnedAt)
        apply(effects, at: returnedAt)
    }

    private func persistSession(
        record: BreakHistoryEntry? = nil,
        at now: Date = Date(),
        activityKind: ActivityKind? = nil
    ) {
        let kind = activityKind ?? currentActivityKind(at: now)
        if let deadline = trackingWindowEnd, now >= deadline,
           let cursor = activityTracker.journal.cursor, cursor.kind == .studying || cursor.kind == .meeting {
            activityTracker.update(to: .kaskasPaused, at: max(cursor.startedAt, deadline))
        }
        trackingWindowEnd = configuration.activeHours.pausesTracking ? engine.activeHoursState?.window?.end : nil
        if let record, record.source == .smartPause, let startedAt = record.startedAt {
            activityTracker.update(to: .breakTime, at: startedAt)
            activityTracker.update(to: .studying, at: record.occurredAt)
        }
        activityTracker.update(to: kind, at: now)
        appUsage.setWorking(hasStarted && kind == .studying, at: now, until: trackingWindowEnd)
        if activityStorageFailed != activityTracker.storageFailed {
            activityStorageFailed = activityTracker.storageFailed
        }
        persistence.save(state: engine.state, record: record)
        historySaveFailed = persistence.historySaveFailed
        refreshScreenTimeToday(at: now)
    }

    private func refreshTyping(active: Bool, at now: Date, showsBreakWarning: Bool = true) {
        let effects = engine.send(.setTyping(active: active), at: now)
        guard !effects.isEmpty else { return }
        apply(effects, at: now, showsBreakWarning: showsBreakWarning)
    }

    private func refreshSnapshot(at now: Date = Date()) {
        let wasProtectionPaused = sessionSnapshot.status.isProtectionPaused
        let previousKind = sessionSnapshot.status.activityKind
        sessionSnapshot = engine.snapshot(at: now)
        let watchesTyping = hasStarted && !sessionSnapshot.outsideActiveHours && configuration.pauseWhileTyping && configuration.breakWarningEnabled
            && (engine.status.isTypingPaused || (!engine.status.isPaused && engine.status.phase == .focusing
                && sessionSnapshot.remaining <= configuration.breakWarningLeadTime))
        if watchesTyping {
            typingMonitor.start { [weak self] active, date in
                self?.refreshTyping(active: active, at: date)
            }
        } else {
            typingMonitor.stop()
        }
        let indicatorEnabled = sessionSnapshot.status.isMeetingPaused ? configuration.meetingPauseIndicatorEnabled
            : (sessionSnapshot.status.isVideoPaused && configuration.videoPauseIndicatorEnabled)
        if !hasStarted || sessionSnapshot.outsideActiveHours || !indicatorEnabled || !sessionSnapshot.status.isProtectionPaused {
            meetingPauseIndicator.dismiss()
        } else if (!wasProtectionPaused || previousKind != sessionSnapshot.status.activityKind),
                  lastProtectionIndicatorAt.map({ now.timeIntervalSince($0) >= 10 * 60 }) ?? true {
            // Shared presentation-only cooldown: detection and timer transitions
            // still run on every signal, including repeated video play/pause.
            lastProtectionIndicatorAt = now
            meetingPauseIndicator.showMeetingPause()
        }
    }

    private func apply(
        _ effects: [SessionEffect],
        at now: Date = Date(),
        showsBreakWarning: Bool = true
    ) {
        if engine.status.isAwaitingReturn && !sessionSnapshot.status.isAwaitingReturn {
            cursorIdleMonitor.resetActivityBaseline()
        }
        refreshSnapshot(at: now)
        for effect in effects {
            switch effect {
            case .dismissMicroReminder:
                microReminderPresenter.dismiss()

            case .dismissBreakWarning:
                breakWarningPresenter.dismiss()

            case .dismissBreak:
                breakPresenter.dismiss()

            case .dismissSkippedBreakReminder:
                skippedBreakNotifier.dismiss()

            case .dismissIdleBreakReminder:
                idleBreakNotifier.dismiss()

            case .showMicroReminder:
                guard configuration.microRemindersEnabled else { break }
                microReminderPresenter.show(
                    displayMode: configuration.microReminderDisplayMode,
                    mascot: configuration.microReminderMascot,
                    color: configuration.microReminderColor,
                    commitmentMode: configuration.microReminderCommitmentMode
                )

            case .showBreakWarning(let endsAt):
                guard showsBreakWarning, configuration.breakWarningEnabled else { break }
                breakWarningPresenter.show(
                    endsAt: endsAt,
                    leadTime: configuration.breakWarningLeadTime,
                    position: configuration.notificationPosition,
                    pausedRemaining: engine.status.isTypingPaused ? sessionSnapshot.remaining : nil,
                    typingIndicatorEnabled: configuration.typingPauseIndicatorEnabled,
                    onStart: { [weak self] in self?.startBreakNow() },
                    onPostpone: { [weak self] duration in self?.postponeBreak(by: duration) },
                    onSkip: { [weak self] in self?.skipUpcomingBreak() }
                )

            case .showBreak(let endsAt):
                breakPresenter.show(
                    endsAt: endsAt,
                    configuration: configuration,
                    isPreview: false,
                    onSnooze: { [weak self] in self?.snoozeBreak() },
                    onSkip: { [weak self] in self?.skipCurrentBreak() },
                    onLockScreen: { SystemAction.lockScreen() },
                    onOpenSettings: { [weak self] in self?.openSettings() }
                )

            case .showSkippedBreakReminder:
                skippedBreakNotifier.show(onStart: { [weak self] in self?.startBreakNow() })

            case .showIdleBreakPrompt(let duration):
                idleBreakNotifier.show(
                    duration: duration,
                    onAccept: { [weak self] in self?.resolveIdleBreak(accepted: true, returnedAt: now) },
                    onDecline: { [weak self] in self?.resolveIdleBreak(accepted: false, returnedAt: now) }
                )

            case .playBreakStartSound:
                playBreakStartSound()

            case .playBreakEndSound:
                playBreakEndSound()

            case .persistSession(let record, let activityKind):
                persistSession(record: record, at: now, activityKind: activityKind)

            case .scheduleNextTick(let date):
                scheduler.schedule(for: date) { [weak self] in
                    self?.reconcile()
                }

            case .cancelScheduler:
                scheduler.cancel()
            }
        }
        refreshScreenTimeToday(at: now)
    }
}
