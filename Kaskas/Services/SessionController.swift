import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class SessionController {
    private(set) var configuration: FocusConfiguration
    private(set) var sessionSnapshot: SessionSnapshot
    private(set) var historySaveFailed = false
    private(set) var activityStorageFailed = false
    private(set) var annotationsRevision = 0
    let appUsage: AppUsageController
    let categoryRegistry: CategoryRegistry
    let launchAtLogin = LaunchAtLoginController()

    var locale: Locale {
        configuration.appLanguage.locale
    }

    @ObservationIgnored private var engine: SessionEngine
    @ObservationIgnored private let scheduler: SessionScheduler
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
    @ObservationIgnored private let meetingMonitor = MeetingActivityMonitor()
    @ObservationIgnored private var checkpointTimer: Timer?
    @ObservationIgnored private var hasStarted = false

    init(
        store: SessionStore = SessionStore(),
        historyStore: (any BreakHistoryRecording)? = nil,
        activityStore: (any ActivityRecording)? = nil,
        appUsageStore: (any AppUsageRecording)? = nil,
        categoryRegistry: CategoryRegistry = CategoryRegistry(),
        scheduler: SessionScheduler = SessionScheduler(),
        microReminderPresenter: MicroReminderPresenter = MicroReminderPresenter(),
        breakWarningPresenter: BreakWarningPresenter = BreakWarningPresenter(),
        breakPresenter: BreakPresenter = BreakPresenter(),
        settingsPresenter: SettingsPresenter = SettingsPresenter(),
        now: Date = Date()
    ) {
        let configuration = store.loadConfiguration()
        self.configuration = configuration
        AppLanguage.currentLocale = configuration.appLanguage.locale
        if UserDefaults.standard.array(forKey: "AppleLanguages") == nil, configuration.appLanguage != .system {
            UserDefaults.standard.set([configuration.appLanguage.rawValue], forKey: "AppleLanguages")
        }
        self.store = store
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

        var engine: SessionEngine
        if let restoredState = store.loadSessionState() {
            engine = SessionEngine(
                configuration: configuration,
                restoredState: restoredState
            )
            if restoredState.idlePauseStartedAt != nil {
                engine.declineIdleBreak(at: store.loadLastActiveAt() ?? now)
            }
            if restoredState.systemPauseStartedAt == nil,
               let lastActiveAt = store.loadLastActiveAt(),
               lastActiveAt <= now {
                engine.beginSystemPause(at: lastActiveAt)
            }
        } else {
            engine = SessionEngine(configuration: configuration, now: now)
        }
        self.engine = engine
        sessionSnapshot = engine.snapshot(at: now)
    }

    func start() {
        guard !hasStarted else {
            return
        }

        hasStarted = true
        engine.prepareForLaunch()
        if configuration.pauseDuringMeetings {
            meetingMonitor.start { [weak self] active in
                guard let self else { return }
                if self.handleMeetingActivity(active, at: Date()) { self.reconcile() }
            }
        }
        let now = Date()
        let meetingActive = configuration.pauseDuringMeetings && meetingMonitor.sample()
        if engine.systemPauseStartedAt != nil {
            engine.endSystemPause(at: now, meetingActive: meetingActive)
            if engine.session.phase == .onBreak {
                // Relaunch stays quiet even when the app closed during a break.
                engine.prepareForLaunch(at: now)
            }
        } else {
            _ = handleMeetingActivity(meetingActive, at: now)
        }
        activityTracker.resume(as: currentActivityKind, at: now)
        appUsage.setWorking(currentActivityKind == .studying, at: now)
        reconcile()
        startIdleMonitoringIfNeeded()
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.persistSession() }
        }
        RunLoop.main.add(timer, forMode: .common)
        checkpointTimer = timer
    }

    func stop() {
        stopIdleMonitoring(at: Date())
        checkpointTimer?.invalidate()
        checkpointTimer = nil
        scheduler.cancel()
        meetingMonitor.stop()
        skippedBreakNotifier.dismiss()
        idleBreakNotifier.dismiss()
        microReminderPresenter.dismiss()
        breakWarningPresenter.dismiss()
        breakPresenter.dismiss()
        settingsPresenter.dismiss()
        let now = Date()
        appUsage.setWorking(false, at: now)
        hasStarted = false
        engine.beginSystemPause(at: now)
        let stoppedKind: ActivityKind = activityTracker.journal.cursor?.kind == .computerInactive
            ? .computerInactive : .kaskasPaused
        persistSession(at: now, activityKind: stoppedKind)
    }

    func systemWillSleep(at now: Date = Date()) {
        stopIdleMonitoring(at: now)
        engine.beginSystemPause(at: now)
        scheduler.cancel()
        microReminderPresenter.dismiss()
        breakWarningPresenter.dismiss()
        breakPresenter.dismiss()
        refreshSnapshot(at: now)
        persistSession(at: now, activityKind: .computerInactive)
    }

    func systemDidWake(at now: Date = Date()) {
        engine.endSystemPause(
            at: now,
            meetingActive: configuration.pauseDuringMeetings && meetingMonitor.sample()
        )
        if engine.manualPauseStartedAt != nil { persistSession(at: now) }
        reconcile(at: now)
        startIdleMonitoringIfNeeded()
    }

    func screenOrSessionDidLock(at now: Date = Date()) {
        guard engine.session.phase == .focusing else { return }
        stopIdleMonitoring(at: now)
        engine.beginSystemPause(at: now)
        scheduler.cancel()
        microReminderPresenter.dismiss()
        breakWarningPresenter.dismiss()
        refreshSnapshot(at: now)
        persistSession(at: now, activityKind: .computerInactive)
    }

    func screenOrSessionDidUnlock(at now: Date = Date()) {
        if engine.systemPauseStartedAt != nil {
            engine.endSystemPause(
                at: now,
                meetingActive: configuration.pauseDuringMeetings && meetingMonitor.sample()
            )
            if engine.manualPauseStartedAt != nil { persistSession(at: now) }
        }
        reconcile(at: now)
        startIdleMonitoringIfNeeded()
    }

    func reconcile(at now: Date = Date(), showsBreakWarning: Bool = true) {
        if configuration.idleDetectionEnabled { cursorIdleMonitor.sample(threshold: configuration.idleThreshold, at: now) }
        guard engine.idlePauseStartedAt == nil else { return }
        guard engine.systemPauseStartedAt == nil, engine.manualPauseStartedAt == nil else { return }
        _ = handleMeetingActivity(
            configuration.pauseDuringMeetings && meetingMonitor.sample(),
            at: now
        )
        let previousSession = engine.session
        let events = engine.process(at: now)
        if events.contains(.breakEnded), configuration.pauseDuringMeetings {
            _ = handleMeetingActivity(meetingMonitor.sample(), at: now)
        }
        refreshSnapshot(at: now)
        let completedBreak = events.contains(.breakEnded)
            ? BreakHistoryEntry.transition(
                from: previousSession, at: now, outcome: .completed, source: .scheduled
            )
            : nil
        persistSession(record: completedBreak, at: now)

        for event in events {
            if event == .breakApproaching, !showsBreakWarning { continue }
            handle(event)
        }

        if events.isEmpty, engine.session.phase == .onBreak {
            presentCurrentBreak()
        }

        if showsBreakWarning,
           engine.session.phase == .focusing,
           configuration.breakWarningEnabled,
           engine.hasShownBreakWarning,
           now < engine.session.endsAt {
            presentBreakWarning()
        }

        scheduleNextEvent()
    }

    func snapshot(at now: Date = Date()) -> SessionSnapshot {
        engine.snapshot(at: now)
    }

    func breaksTakenToday(at now: Date = Date()) -> Int {
        engine.breaksTakenToday(at: now)
    }

    func activityIntervals(from start: Date, to end: Date, now: Date = Date()) -> [ActivityInterval] {
        let intervals = activityTracker.intervals(from: start, to: end, now: now)
        activityStorageFailed = activityTracker.storageFailed
        return intervals
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
        guard let breakHistoryStore else { return [] }
        return (try? breakHistoryStore.entries(from: start, to: end.addingTimeInterval(0.001))) ?? []
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
            engine.endMeetingPause(at: now)
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
        self.configuration = configuration
        if !configuration.pauseDuringMeetings {
            meetingMonitor.stop()
            engine.endMeetingPause(at: now)
        } else if !self.engine.configuration.pauseDuringMeetings {
            meetingMonitor.start { [weak self] active in
                guard let self else { return }
                if self.handleMeetingActivity(active, at: Date()) { self.reconcile() }
            }
        }
        engine.updateConfiguration(configuration, at: now)
        store.save(configuration: configuration)
        if idleSettingsChanged { startIdleMonitoringIfNeeded() }
        if engine.manualPauseStartedAt != nil {
            refreshSnapshot(at: now)
            persistSession(at: now)
        } else {
            reconcile(at: now, showsBreakWarning: !warningSettingsChanged)
        }
        if warningSettingsChanged,
           engine.session.phase == .focusing,
           engine.hasShownBreakWarning {
            breakWarningPresenter.suppress(endsAt: engine.session.endsAt)
        }
    }

    func startBreakNow() {
        let now = Date()
        if engine.idlePauseStartedAt != nil { resolveIdleBreak(accepted: false, returnedAt: now) }
        skippedBreakNotifier.dismiss()
        breakWarningPresenter.dismiss()
        engine.startBreak(at: now, scheduled: false)
        refreshSnapshot(at: now)
        persistSession(at: now)
        presentCurrentBreak()
        playBreakStartSound()
        scheduleNextEvent()
    }

    func snooze() {
        let now = Date()
        engine.snooze()
        breakWarningPresenter.dismiss()
        refreshSnapshot()
        persistSession(at: now)
        scheduleNextEvent()
    }

    func snoozeBreak() {
        let now = Date()
        engine.snoozeBreak(at: now)
        refreshSnapshot(at: now)
        breakPresenter.dismiss()
        persistSession(at: now)
        scheduleNextEvent()
    }

    func openSettings() {
        breakPresenter.dismiss()
        settingsPresenter.show(controller: self)
    }

    func toggleManualPause() {
        let now = Date()
        if engine.idlePauseStartedAt != nil { resolveIdleBreak(accepted: false, returnedAt: now) }
        if engine.manualPauseStartedAt == nil {
            engine.beginManualPause(at: now)
            guard engine.manualPauseStartedAt != nil else { return }
            scheduler.cancel()
            microReminderPresenter.dismiss()
            breakWarningPresenter.dismiss()
            breakPresenter.dismiss()
            skippedBreakNotifier.dismiss()
            refreshSnapshot(at: now)
            persistSession(at: now)
        } else {
            engine.endManualPause(at: now)
            reconcile(at: now)
        }
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
        if engine.session.phase == .focusing,
           engine.hasShownBreakWarning,
           Date.now < engine.session.endsAt {
            return
        }
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

#if DEBUG
    func previewSkippedBreakReminder() {
        skippedBreakNotifier.show(onStart: { [weak self] in self?.previewBreak() })
    }

    func dismissPreviews() {
        microReminderPresenter.dismissPreview()
        breakWarningPresenter.dismissPreview()
        breakPresenter.dismissPreview()
        skippedBreakNotifier.dismiss()
    }
#endif

    func skipCurrentBreak() {
        let now = Date()
        let previousSession = engine.session
        breakWarningPresenter.dismiss()
        let shouldSuggestBreak = engine.skipBreak(at: now)
        refreshSnapshot(at: now)
        breakPresenter.dismiss()
        persistSession(record: .transition(
            from: previousSession, at: now, outcome: .skipped, source: .manual
        ), at: now)
        scheduleNextEvent()
        if shouldSuggestBreak { presentSkippedBreakReminder() }
    }

    func completeBreak() {
        let now = Date()
        let previousSession = engine.session
        breakWarningPresenter.dismiss()
        engine.completeBreak(at: now)
        refreshSnapshot(at: now)
        breakPresenter.dismiss()
        persistSession(record: previousSession.phase == .onBreak ? .transition(
            from: previousSession, at: now, outcome: .completed, source: .manual
        ) : nil, at: now)
        if previousSession.phase == .onBreak { playBreakEndSound() }
        scheduleNextEvent()
    }

    private func handle(_ event: SessionEvent) {
        switch event {
        case .microReminderDue:
            microReminderPresenter.show(
                mascot: configuration.microReminderMascot,
                color: configuration.microReminderColor
            )

        case .breakApproaching:
            microReminderPresenter.dismiss()
            presentBreakWarning()

        case .fullBreakDue:
            microReminderPresenter.dismiss()
            breakWarningPresenter.dismiss()
            presentCurrentBreak()
            playBreakStartSound()

        case .breakEnded:
            breakPresenter.dismiss()
            playBreakEndSound()
        }
    }

    private func playBreakStartSound() {
        guard configuration.breakSoundEnabled else { return }
        BreakSoundPlayer.play(configuration.breakSound)
    }

    private func playBreakEndSound() {
        guard configuration.breakEndSoundEnabled else { return }
        BreakSoundPlayer.play(configuration.breakEndSound)
    }

    private func presentBreakWarning() {
        guard configuration.breakWarningEnabled else { return }
        breakWarningPresenter.show(
            endsAt: engine.session.endsAt,
            leadTime: configuration.breakWarningLeadTime,
            position: configuration.notificationPosition,
            onStart: { [weak self] in self?.startBreakNow() },
            onPostpone: { [weak self] duration in self?.postponeBreak(by: duration) },
            onSkip: { [weak self] in self?.skipUpcomingBreak() }
        )
    }

    private func postponeBreak(by duration: TimeInterval) {
        engine.postponeBreak(by: duration)
        breakWarningPresenter.dismiss()
        refreshSnapshot()
        persistSession()
        scheduleNextEvent()
    }

    private func skipUpcomingBreak() {
        let now = Date()
        let previousSession = engine.session
        let shouldSuggestBreak = engine.skipBreak(at: now)
        breakWarningPresenter.dismiss()
        refreshSnapshot(at: now)
        persistSession(record: .transition(
            from: previousSession, at: now, outcome: .skipped, source: .manual
        ), at: now)
        scheduleNextEvent()
        if shouldSuggestBreak { presentSkippedBreakReminder() }
    }

    private func presentSkippedBreakReminder() {
        skippedBreakNotifier.show(onStart: { [weak self] in self?.startBreakNow() })
    }

    private func presentCurrentBreak() {
        breakPresenter.show(
            endsAt: engine.session.endsAt,
            configuration: configuration,
            isPreview: false,
            onSnooze: { [weak self] in
                self?.snoozeBreak()
            },
            onSkip: { [weak self] in
                self?.skipCurrentBreak()
            },
            onLockScreen: {
                SystemAction.lockScreen()
            },
            onOpenSettings: { [weak self] in
                self?.openSettings()
            }
        )
    }

    private func scheduleNextEvent() {
        guard engine.systemPauseStartedAt == nil, engine.manualPauseStartedAt == nil,
              engine.idlePauseStartedAt == nil else {
            scheduler.cancel()
            return
        }
        if configuration.pauseDuringMeetings,
           handleMeetingActivity(meetingMonitor.sample(), at: Date()) {
            persistSession()
        }
        scheduler.schedule(for: engine.nextEventDate) { [weak self] in
            self?.reconcile()
        }
    }

    @discardableResult
    private func handleMeetingActivity(_ active: Bool, at now: Date) -> Bool {
        let wasPaused = engine.meetingPauseStartedAt != nil
        if active {
            engine.beginMeetingPause(at: now)
        } else {
            engine.endMeetingPause(at: now)
        }
        let isPaused = engine.meetingPauseStartedAt != nil
        guard wasPaused != isPaused else { return false }
        if isPaused {
            microReminderPresenter.dismiss()
            breakWarningPresenter.dismiss()
        }
        refreshSnapshot(at: now)
        return true
    }

    private var currentActivityKind: ActivityKind {
        if engine.systemPauseStartedAt != nil {
            return activityTracker.journal.cursor?.kind ?? .computerInactive
        }
        if engine.manualPauseStartedAt != nil { return .kaskasPaused }
        if engine.meetingPauseStartedAt != nil { return .meeting }
        if engine.idlePauseStartedAt != nil { return .computerInactive }
        return engine.session.phase == .focusing ? .studying : .breakTime
    }

    private func startIdleMonitoringIfNeeded() {
        guard configuration.idleDetectionEnabled else { return }
        cursorIdleMonitor.onIdle = { [weak self] startedAt in self?.beginIdleBreak(at: startedAt) }
        cursorIdleMonitor.onReturn = { [weak self] _, returnedAt in
            self?.presentIdleBreak(returnedAt: returnedAt)
        }
        cursorIdleMonitor.start(threshold: configuration.idleThreshold)
    }

    private func stopIdleMonitoring(at now: Date) {
        cursorIdleMonitor.stop()
        idleBreakNotifier.dismiss()
        if engine.idlePauseStartedAt != nil {
            engine.declineIdleBreak(at: now)
            refreshSnapshot(at: now)
            persistSession(at: now)
        }
    }

    private func beginIdleBreak(at startedAt: Date) {
        let idleStart = max(engine.session.startedAt, startedAt)
        engine.beginIdlePause(at: idleStart)
        guard engine.idlePauseStartedAt != nil else { return }
        scheduler.cancel()
        microReminderPresenter.dismiss()
        breakWarningPresenter.dismiss()
        refreshSnapshot(at: idleStart)
        persistSession(at: idleStart)
    }

    private func presentIdleBreak(returnedAt: Date) {
        guard let actualStart = engine.idlePauseStartedAt else { return }
        idleBreakNotifier.show(
            duration: returnedAt.timeIntervalSince(actualStart),
            onAccept: { [weak self] in self?.resolveIdleBreak(accepted: true, returnedAt: returnedAt) },
            onDecline: { [weak self] in self?.resolveIdleBreak(accepted: false, returnedAt: returnedAt) }
        )
    }

    private func resolveIdleBreak(accepted: Bool, returnedAt: Date) {
        guard let startedAt = engine.idlePauseStartedAt else { return }
        idleBreakNotifier.dismiss()
        let previousSession = engine.session
        if accepted {
            activityTracker.update(to: .breakTime, at: startedAt)
            activityTracker.update(to: .studying, at: returnedAt)
            engine.acceptIdleBreak(at: returnedAt)
        } else {
            engine.declineIdleBreak(at: returnedAt)
        }
        refreshSnapshot(at: returnedAt)
        persistSession(
            record: accepted ? .idleBreak(from: previousSession, startedAt: startedAt, returnedAt: returnedAt) : nil,
            at: returnedAt
        )
        reconcile()
    }

    private func persistSession(
        record: BreakHistoryEntry? = nil,
        at now: Date = Date(),
        activityKind: ActivityKind? = nil
    ) {
        let kind = activityKind ?? currentActivityKind
        activityTracker.update(to: kind, at: now)
        appUsage.setWorking(hasStarted && kind == .studying, at: now)
        activityStorageFailed = activityTracker.storageFailed
        persistence.save(state: engine.state, record: record)
        historySaveFailed = persistence.historySaveFailed
    }

    private func refreshSnapshot(at now: Date = Date()) {
        sessionSnapshot = engine.snapshot(at: now)
    }
}
