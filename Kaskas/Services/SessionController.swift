import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class SessionController {
    private(set) var configuration: FocusConfiguration
    private(set) var sessionSnapshot: SessionSnapshot

    @ObservationIgnored private var engine: SessionEngine
    @ObservationIgnored private let scheduler: SessionScheduler
    @ObservationIgnored private let store: SessionStore
    @ObservationIgnored private let microReminderPresenter: MicroReminderPresenter
    @ObservationIgnored private let breakWarningPresenter: BreakWarningPresenter
    @ObservationIgnored private let breakPresenter: BreakPresenter
    @ObservationIgnored private let settingsPresenter: SettingsPresenter
    @ObservationIgnored private let idleMonitor = IdleActivityMonitor()
    @ObservationIgnored private let smartPausePresenter = SmartPausePresenter()
    @ObservationIgnored private let triggerMonitor = SmartPauseTriggerMonitor()
    @ObservationIgnored private let smartPauseNotifier = SmartPauseNotifier()
    @ObservationIgnored private let skippedBreakNotifier = SkippedBreakNotifier()
    @ObservationIgnored private var activeTriggers = Set<SmartPauseTrigger>()
    @ObservationIgnored private var lastTriggerPauseEndedAt: Date?
    @ObservationIgnored private var isSmartPausePromptVisible = false
    @ObservationIgnored private var hasStarted = false

    init(
        store: SessionStore = SessionStore(),
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
        self.scheduler = scheduler
        self.microReminderPresenter = microReminderPresenter
        self.breakWarningPresenter = breakWarningPresenter
        self.breakPresenter = breakPresenter
        self.settingsPresenter = settingsPresenter

        let engine: SessionEngine
        if let restoredState = store.loadSessionState() {
            engine = SessionEngine(
                configuration: configuration,
                restoredState: restoredState
            )
        } else {
            engine = SessionEngine(configuration: configuration, now: now)
        }
        self.engine = engine
        sessionSnapshot = engine.snapshot(at: now)
        triggerMonitor.configuration = configuration
    }

    func start() {
        guard !hasStarted else {
            return
        }

        hasStarted = true
        engine.prepareForLaunch()
        if !configuration.smartPauseEnabled, engine.pendingIdleStartedAt != nil {
            engine.resolveSmartPause(countAsBreak: false, at: Date())
        }
        idleMonitor.start { [weak self] now, idleSeconds in
            self?.handleActivitySample(at: now, idleSeconds: idleSeconds)
        }
        triggerMonitor.start { [weak self] now, triggers in
            guard let self else { return }
            if self.handleTriggerSample(at: now, triggers: triggers) {
                self.reconcile(at: now)
            }
        }
        reconcile()
    }

    func stop() {
        scheduler.cancel()
        idleMonitor.stop()
        triggerMonitor.stop()
        smartPausePresenter.dismiss()
        smartPauseNotifier.dismiss()
        skippedBreakNotifier.dismiss()
        microReminderPresenter.dismiss()
        breakWarningPresenter.dismiss()
        breakPresenter.dismiss()
        settingsPresenter.dismiss()
        persistSession()
    }

    func reconcile(at now: Date = Date()) {
        _ = handleTriggerSample(at: now, triggers: triggerMonitor.activeTriggers())
        if configuration.smartPauseEnabled {
            let idleSeconds = CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: .null)
            if idleSeconds.isFinite, idleSeconds >= 0 {
                handleActivitySample(at: now, idleSeconds: idleSeconds)
            }
        }
        guard engine.pendingIdleStartedAt == nil,
              engine.triggerPauseStartedAt == nil else {
            refreshSnapshot(at: now)
            persistSession()
            scheduler.cancel()
            return
        }
        let events = engine.process(at: now)
        refreshSnapshot(at: now)
        persistSession()

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

    var isPaused: Bool {
        engine.pendingIdleStartedAt != nil || engine.triggerPauseStartedAt != nil
    }

    func breaksTakenToday(at now: Date = Date()) -> Int {
        engine.breaksTakenToday(at: now)
    }

    func updateConfiguration(_ configuration: FocusConfiguration) {
        let now = Date()
        let previousConfiguration = self.configuration
        if configuration.focusDuration != self.configuration.focusDuration {
            breakWarningPresenter.dismiss()
        }
        self.configuration = configuration
        triggerMonitor.configuration = configuration
        if !previousConfiguration.notifyDuringCalls && configuration.notifyDuringCalls,
           activeTriggers.contains(.calls) {
            smartPauseNotifier.notify(trigger: .calls)
        }
        if !previousConfiguration.notifyDuringVideo && configuration.notifyDuringVideo,
           activeTriggers.contains(.video) {
            smartPauseNotifier.notify(trigger: .video)
        }
        if !previousConfiguration.notifyForFocusApps && configuration.notifyForFocusApps,
           activeTriggers.contains(.focusApp) {
            smartPauseNotifier.notify(trigger: .focusApp)
        }
        if !configuration.smartPauseEnabled, engine.pendingIdleStartedAt != nil {
            resolveSmartPause(countAsBreak: false, at: now)
        }
        engine.updateConfiguration(configuration, at: now)
        store.save(configuration: configuration)
        reconcile(at: now)
    }

    func startBreakNow() {
        let now = Date()
        skippedBreakNotifier.dismiss()
        breakWarningPresenter.dismiss()
        engine.endTriggerPause(at: now)
        engine.startBreak(at: now)
        refreshSnapshot(at: now)
        persistSession()
        presentCurrentBreak()
        scheduleNextEvent()
    }

    func snooze() {
        engine.snooze()
        breakWarningPresenter.dismiss()
        refreshSnapshot()
        persistSession()
        scheduleNextEvent()
    }

    func snoozeBreak() {
        let now = Date()
        engine.snoozeBreak(at: now)
        refreshSnapshot(at: now)
        breakPresenter.dismiss()
        persistSession()
        scheduleNextEvent()
    }

    func openSettings() {
        breakPresenter.dismiss()
        settingsPresenter.show(controller: self)
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
        breakWarningPresenter.dismiss()
        let shouldSuggestBreak = engine.skipBreak(at: now)
        refreshSnapshot(at: now)
        breakPresenter.dismiss()
        persistSession()
        scheduleNextEvent()
        if shouldSuggestBreak { presentSkippedBreakReminder() }
    }

    func completeBreak() {
        let now = Date()
        breakWarningPresenter.dismiss()
        engine.completeBreak(at: now)
        refreshSnapshot(at: now)
        breakPresenter.dismiss()
        persistSession()
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

        case .breakEnded:
            breakPresenter.dismiss()
        }
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
        let shouldSuggestBreak = engine.skipBreak(at: now)
        breakWarningPresenter.dismiss()
        refreshSnapshot(at: now)
        persistSession()
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
        guard engine.pendingIdleStartedAt == nil,
              engine.triggerPauseStartedAt == nil else {
            scheduler.cancel()
            return
        }
        scheduler.schedule(for: engine.nextEventDate) { [weak self] in
            self?.reconcile()
        }
    }

    private func handleActivitySample(at now: Date, idleSeconds: TimeInterval) {
        guard configuration.smartPauseEnabled else { return }
        let lastActivityAt = now.addingTimeInterval(-idleSeconds)
        let effectiveIdleStartedAt = max(lastActivityAt, lastTriggerPauseEndedAt ?? lastActivityAt)
        let effectiveIdleSeconds = max(0, now.timeIntervalSince(effectiveIdleStartedAt))
        if engine.pendingIdleStartedAt == nil {
            guard engine.session.phase == .focusing,
                  effectiveIdleSeconds >= configuration.smartPauseIdleDuration else { return }
            engine.beginSmartPause(at: effectiveIdleStartedAt)
            guard engine.pendingIdleStartedAt != nil else { return }
            microReminderPresenter.dismiss()
            breakWarningPresenter.dismiss()
            refreshSnapshot(at: now)
            persistSession()
            scheduler.cancel()
        } else if effectiveIdleSeconds < configuration.smartPauseIdleDuration,
                  !isSmartPausePromptVisible {
            isSmartPausePromptVisible = true
            smartPausePresenter.show(
                onCountAsBreak: { [weak self] in
                    self?.resolveSmartPause(countAsBreak: true, at: Date())
                },
                onIgnore: { [weak self] in
                    self?.resolveSmartPause(countAsBreak: false, at: Date())
                }
            )
        }
    }

    private func resolveSmartPause(countAsBreak: Bool, at now: Date) {
        smartPausePresenter.dismiss()
        isSmartPausePromptVisible = false
        engine.resolveSmartPause(countAsBreak: countAsBreak, at: now)
        reconcile(at: now)
    }

    private func handleTriggerSample(at now: Date, triggers: Set<SmartPauseTrigger>) -> Bool {
        let previous = activeTriggers
        activeTriggers = triggers
        if !triggers.isEmpty {
            guard engine.pendingIdleStartedAt == nil,
                  engine.session.phase == .focusing else { return false }
            let wasPaused = engine.triggerPauseStartedAt != nil
            engine.beginTriggerPause(at: now)
            guard engine.triggerPauseStartedAt != nil else { return false }
            for trigger in triggers.subtracting(previous) where shouldNotify(for: trigger) {
                smartPauseNotifier.notify(trigger: trigger)
            }
            if !wasPaused {
                microReminderPresenter.dismiss()
                breakWarningPresenter.dismiss()
                refreshSnapshot(at: now)
                persistSession()
                scheduler.cancel()
                return true
            }
            return false
        }
        guard engine.triggerPauseStartedAt != nil else { return false }
        engine.endTriggerPause(at: now, resumeDelay: configuration.smartPauseResumeDelay)
        lastTriggerPauseEndedAt = now
        refreshSnapshot(at: now)
        persistSession()
        return true
    }

    private func shouldNotify(for trigger: SmartPauseTrigger) -> Bool {
        switch trigger {
        case .calls: configuration.notifyDuringCalls
        case .video: configuration.notifyDuringVideo
        case .focusApp: configuration.notifyForFocusApps
        }
    }

    private func persistSession() {
        store.save(state: engine.state)
    }

    private func refreshSnapshot(at now: Date = Date()) {
        sessionSnapshot = engine.snapshot(at: now)
    }
}
