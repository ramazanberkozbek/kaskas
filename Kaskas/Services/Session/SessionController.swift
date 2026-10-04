import AppKit
import Foundation
import Observation

/// The puppet master and central brain of Kaskas.
///
/// If this class breaks, the entire app has an existential crisis. It sits between
/// pure mathematical state (`SessionEngine`) and the messy real world coordinating
/// timers, spying on hardware, and ultimately deciding when you need to touch grass.
///
/// What the maestro actually does:
/// - Dictates the focus & break lifecycle (and tolerates your desperate snooze clicks).
/// - Keeps an eye on your camera and mic so it doesn't embarrass you during Zoom calls.
/// - Detects when you abandon your Mac for coffee and counts it as a natural break.
/// - Tracks which apps steal your focus and silently logs them to SwiftData.
/// - Hijacks your screen when it's break time and locks it if you asked for tough love.
/// - Survives system sleep, restarts, and random macOS panics without losing a second.
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
    @ObservationIgnored private let cursorIdleMonitor = CursorIdleMonitor()
    @ObservationIgnored private let meetingMonitor: any MeetingActivityMonitoring
    @ObservationIgnored private var checkpointTimer: Timer?
    @ObservationIgnored private var hasStarted = false
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
        categoryRegistry: CategoryRegistry = CategoryRegistry(),
        scheduler: SessionScheduler = SessionScheduler(),
        microReminderPresenter: MicroReminderPresenter = MicroReminderPresenter(),
        breakWarningPresenter: BreakWarningPresenter = BreakWarningPresenter(),
        breakPresenter: BreakPresenter = BreakPresenter(),
        settingsPresenter: SettingsPresenter = SettingsPresenter(),
        meetingMonitor: any MeetingActivityMonitoring = MeetingActivityMonitor(),
        now: Date = Date()
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
        self.categoryRegistry = categoryRegistry
        appUsage = AppUsageController(sessionStore: store, registry: categoryRegistry, usageStore: appUsageStore)
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

    func start() {
        guard !hasStarted else {
            return
        }

        hasStarted = true
        if configuration.pauseDuringMeetings {
            meetingMonitor.start { [weak self] active in
                guard let self else { return }
                MainActor.assumeIsolated {
                    self.handleMeetingActivity(active)
                }
            }
        }
        let now = Date()
        let meetingActive = configuration.pauseDuringMeetings && meetingMonitor.sample()
        let effects = engine.send(.launch(meetingActive: meetingActive), at: now)
        activityTracker.resume(as: currentActivityKind, at: now)
        appUsage.setWorking(currentActivityKind == .studying, at: now)
        apply(effects, at: now)
        startIdleMonitoringIfNeeded()
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.persistSession() }
        }
        RunLoop.main.add(timer, forMode: .common)
        checkpointTimer = timer
    }

    func stop() {
        wallpaperImportID = nil
        stopIdleMonitoring(at: Date())
        checkpointTimer?.invalidate()
        checkpointTimer = nil
        meetingMonitor.stop()
        settingsPresenter.dismiss()
        let now = Date()
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
        let effects = engine.send(.systemResumed(meetingActive: meetingActive), at: now)
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
        let effects = engine.send(.systemResumed(meetingActive: meetingActive), at: now)
        apply(effects, at: now)
        startIdleMonitoringIfNeeded()
    }

    func reconcile(at now: Date = Date(), showsBreakWarning: Bool = true) {
        if configuration.idleDetectionEnabled {
            cursorIdleMonitor.sample(threshold: configuration.idleThreshold, at: now)
        }
        if configuration.pauseDuringMeetings {
            let meetingActive = meetingMonitor.sample()
            let meetingEffects = engine.send(.setMeeting(active: meetingActive), at: now)
            apply(meetingEffects, at: now, showsBreakWarning: showsBreakWarning)
        }
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
            return base + max(0, now.timeIntervalSince(effectiveStart))
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

    func updateConfiguration(_ configuration: FocusConfiguration) {
        let now = Date()
        let idleSettingsChanged = configuration.idleDetectionEnabled != self.configuration.idleDetectionEnabled
            || configuration.idleThreshold != self.configuration.idleThreshold
        let warningSettingsChanged = configuration.breakWarningEnabled != self.configuration.breakWarningEnabled
            || configuration.breakWarningLeadTime != self.configuration.breakWarningLeadTime
            || configuration.notificationPosition != self.configuration.notificationPosition
        if idleSettingsChanged { stopIdleMonitoring(at: now) }
        if warningSettingsChanged {
            breakWarningPresenter.dismiss()
        }
        if configuration.focusDuration != self.configuration.focusDuration {
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
        let dockVisibilityChanged = configuration.showInDock != self.configuration.showInDock
        if configuration.breakBackground != self.configuration.breakBackground
            || configuration.customWallpaperPath != self.configuration.customWallpaperPath {
            wallpaperImportID = nil
        }
        self.configuration = configuration
        if dockVisibilityChanged { applyDockVisibility() }
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
        if meetingDetectionEnabled {
            let meetingEffects = engine.send(.setMeeting(active: meetingMonitor.sample()), at: now)
            apply(meetingEffects, at: now)
        }
        if idleSettingsChanged { startIdleMonitoringIfNeeded() }
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

    func openSettings() {
        breakPresenter.dismiss()
        settingsPresenter.show(controller: self)
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
        microReminderPresenter.show(
            mascot: configuration.microReminderMascot,
            color: configuration.microReminderColor,
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
        let effects = engine.send(.setMeeting(active: active), at: Date())
        apply(effects)
    }

    private func playBreakStartSound() {
        guard configuration.breakSoundEnabled else { return }
        BreakSoundPlayer.play(configuration.breakSound)
    }

    private func playBreakEndSound() {
        guard configuration.breakEndSoundEnabled else { return }
        BreakSoundPlayer.play(configuration.breakEndSound)
    }

    private var currentActivityKind: ActivityKind {
        if engine.status.isSystemPaused {
            return activityTracker.journal.cursor?.kind ?? .computerInactive
        }
        return engine.status.activityKind
    }

    private func startIdleMonitoringIfNeeded() {
        guard configuration.idleDetectionEnabled else { return }
        cursorIdleMonitor.onIdle = { [weak self] startedAt in
            self?.beginIdleBreak(at: startedAt)
        }
        cursorIdleMonitor.onReturn = { [weak self] _, returnedAt in
            self?.presentIdleBreak(returnedAt: returnedAt)
        }
        cursorIdleMonitor.start(threshold: configuration.idleThreshold)
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
        let kind = activityKind ?? currentActivityKind
        if let record, record.source == .smartPause, let startedAt = record.startedAt {
            activityTracker.update(to: .breakTime, at: startedAt)
            activityTracker.update(to: .studying, at: record.occurredAt)
        }
        activityTracker.update(to: kind, at: now)
        appUsage.setWorking(hasStarted && kind == .studying, at: now)
        if activityStorageFailed != activityTracker.storageFailed {
            activityStorageFailed = activityTracker.storageFailed
        }
        persistence.save(state: engine.state, record: record)
        historySaveFailed = persistence.historySaveFailed
        refreshScreenTimeToday(at: now)
    }

    private func refreshSnapshot(at now: Date = Date()) {
        sessionSnapshot = engine.snapshot(at: now)
    }

    private func apply(
        _ effects: [SessionEffect],
        at now: Date = Date(),
        showsBreakWarning: Bool = true
    ) {
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
                microReminderPresenter.show(
                    mascot: configuration.microReminderMascot,
                    color: configuration.microReminderColor
                )

            case .showBreakWarning(let endsAt):
                guard showsBreakWarning, configuration.breakWarningEnabled else { break }
                breakWarningPresenter.show(
                    endsAt: endsAt,
                    leadTime: configuration.breakWarningLeadTime,
                    position: configuration.notificationPosition,
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
