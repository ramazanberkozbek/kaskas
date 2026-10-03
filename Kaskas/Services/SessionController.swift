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
        } else if !self.engine.configuration.pauseDuringMeetings {
            meetingMonitor.start { [weak self] active in
                guard let self else { return }
                MainActor.assumeIsolated { self.handleMeetingActivity(active) }
            }
        }
        let effects = engine.send(.updateConfiguration(configuration), at: now)
        store.save(configuration: configuration)
        apply(effects, at: now, showsBreakWarning: !warningSettingsChanged)
        if idleSettingsChanged { startIdleMonitoringIfNeeded() }
        if warningSettingsChanged,
           engine.status.phase == .focusing,
           engine.hasShownBreakWarning {
            breakWarningPresenter.suppress(endsAt: engine.session.endsAt)
        }
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
        if engine.status.phase == .focusing,
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
        activityStorageFailed = activityTracker.storageFailed
        persistence.save(state: engine.state, record: record)
        historySaveFailed = persistence.historySaveFailed
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
    }
}
