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

    @ObservationIgnored private var engine: SessionEngine
    @ObservationIgnored private let scheduler: SessionScheduler
    @ObservationIgnored private let store: SessionStore
    @ObservationIgnored private let persistence: SessionPersistence
    @ObservationIgnored private let activityTracker: ActivityTracker
    @ObservationIgnored private let microReminderPresenter: MicroReminderPresenter
    @ObservationIgnored private let breakWarningPresenter: BreakWarningPresenter
    @ObservationIgnored private let breakPresenter: BreakPresenter
    @ObservationIgnored private let settingsPresenter: SettingsPresenter
    @ObservationIgnored private let skippedBreakNotifier = SkippedBreakNotifier()
    @ObservationIgnored private let meetingMonitor = MeetingActivityMonitor()
    @ObservationIgnored private var checkpointTimer: Timer?
    @ObservationIgnored private var hasStarted = false

    init(
        store: SessionStore = SessionStore(),
        historyStore: (any BreakHistoryRecording)? = nil,
        activityStore: (any ActivityRecording)? = nil,
        scheduler: SessionScheduler = SessionScheduler(),
        microReminderPresenter: MicroReminderPresenter = MicroReminderPresenter(),
        breakWarningPresenter: BreakWarningPresenter = BreakWarningPresenter(),
        breakPresenter: BreakPresenter = BreakPresenter(),
        settingsPresenter: SettingsPresenter = SettingsPresenter(),
        now: Date = Date()
    ) {
        let configuration = store.loadConfiguration()
        self.configuration = configuration
        self.store = store
        persistence = SessionPersistence(store: store, historyStore: historyStore)
        activityTracker = ActivityTracker(sessionStore: store, activityStore: activityStore)
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
        reconcile()
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.persistSession() }
        }
        RunLoop.main.add(timer, forMode: .common)
        checkpointTimer = timer
    }

    func stop() {
        checkpointTimer?.invalidate()
        checkpointTimer = nil
        scheduler.cancel()
        meetingMonitor.stop()
        skippedBreakNotifier.dismiss()
        microReminderPresenter.dismiss()
        breakWarningPresenter.dismiss()
        breakPresenter.dismiss()
        settingsPresenter.dismiss()
        let now = Date()
        engine.beginSystemPause(at: now)
        let stoppedKind: ActivityKind = activityTracker.journal.cursor?.kind == .computerInactive
            ? .computerInactive : .kaskasPaused
        persistSession(at: now, activityKind: stoppedKind)
    }

    func systemWillSleep(at now: Date = Date()) {
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
    }

    func reconcile(at now: Date = Date()) {
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
            handle(event)
        }

        if events.isEmpty, engine.session.phase == .onBreak {
            presentCurrentBreak()
        }

        if engine.session.phase == .focusing,
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

    func updateConfiguration(_ configuration: FocusConfiguration) {
        let now = Date()
        if configuration.focusDuration != self.configuration.focusDuration {
            breakWarningPresenter.dismiss()
            engine.endMeetingPause(at: now)
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
        if engine.manualPauseStartedAt != nil {
            refreshSnapshot(at: now)
            persistSession(at: now)
        } else {
            reconcile(at: now)
        }
    }

    func startBreakNow() {
        let now = Date()
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

#if DEBUG
    func previewBreakWarning() {
        breakWarningPresenter.show(
            endsAt: Date.now.addingTimeInterval(SessionEngine.breakWarningLeadTime),
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
        breakWarningPresenter.show(
            endsAt: engine.session.endsAt,
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
        guard engine.systemPauseStartedAt == nil, engine.manualPauseStartedAt == nil else {
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
        if engine.meetingPauseStartedAt != nil || engine.manualPauseStartedAt != nil { return .kaskasPaused }
        return engine.session.phase == .focusing ? .studying : .breakTime
    }

    private func persistSession(
        record: BreakHistoryEntry? = nil,
        at now: Date = Date(),
        activityKind: ActivityKind? = nil
    ) {
        activityTracker.update(to: activityKind ?? currentActivityKind, at: now)
        activityStorageFailed = activityTracker.storageFailed
        persistence.save(state: engine.state, record: record)
        historySaveFailed = persistence.historySaveFailed
    }

    private func refreshSnapshot(at now: Date = Date()) {
        sessionSnapshot = engine.snapshot(at: now)
    }
}
