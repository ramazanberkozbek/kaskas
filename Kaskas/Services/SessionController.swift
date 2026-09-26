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
    @ObservationIgnored private let historyStore: BreakHistoryStore?
    @ObservationIgnored private var pendingHistoryEntries: [BreakHistoryEntry] = []
    @ObservationIgnored private let microReminderPresenter: MicroReminderPresenter
    @ObservationIgnored private let breakWarningPresenter: BreakWarningPresenter
    @ObservationIgnored private let breakPresenter: BreakPresenter
    @ObservationIgnored private let settingsPresenter: SettingsPresenter
    @ObservationIgnored private let skippedBreakNotifier = SkippedBreakNotifier()
    @ObservationIgnored private var hasStarted = false

    init(
        store: SessionStore = SessionStore(),
        historyStore: BreakHistoryStore? = nil,
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
        self.historyStore = historyStore
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
    }

    func start() {
        guard !hasStarted else {
            return
        }

        hasStarted = true
        engine.prepareForLaunch()
        reconcile()
    }

    func stop() {
        scheduler.cancel()
        skippedBreakNotifier.dismiss()
        microReminderPresenter.dismiss()
        breakWarningPresenter.dismiss()
        breakPresenter.dismiss()
        settingsPresenter.dismiss()
        persistSession()
    }

    func reconcile(at now: Date = Date()) {
        let previousSession = engine.session
        let events = engine.process(at: now)
        refreshSnapshot(at: now)
        let completedBreak = events.contains(.breakEnded)
            ? BreakHistoryEntry.transition(
                from: previousSession, at: now, outcome: .completed, source: .scheduled
            )
            : nil
        persistSession(record: completedBreak)

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

    func updateConfiguration(_ configuration: FocusConfiguration) {
        let now = Date()
        if configuration.focusDuration != self.configuration.focusDuration {
            breakWarningPresenter.dismiss()
        }
        self.configuration = configuration
        engine.updateConfiguration(configuration, at: now)
        store.save(configuration: configuration)
        reconcile(at: now)
    }

    func startBreakNow() {
        let now = Date()
        skippedBreakNotifier.dismiss()
        breakWarningPresenter.dismiss()
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
        let previousSession = engine.session
        breakWarningPresenter.dismiss()
        let shouldSuggestBreak = engine.skipBreak(at: now)
        refreshSnapshot(at: now)
        breakPresenter.dismiss()
        persistSession(record: .transition(
            from: previousSession, at: now, outcome: .skipped, source: .manual
        ))
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
        ) : nil)
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
        let previousSession = engine.session
        let shouldSuggestBreak = engine.skipBreak(at: now)
        breakWarningPresenter.dismiss()
        refreshSnapshot(at: now)
        persistSession(record: .transition(
            from: previousSession, at: now, outcome: .skipped, source: .manual
        ))
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
        scheduler.schedule(for: engine.nextEventDate) { [weak self] in
            self?.reconcile()
        }
    }

    private func persistSession(record: BreakHistoryEntry? = nil) {
        if let record { pendingHistoryEntries.append(record) }
        if let historyStore {
            do {
                for entry in pendingHistoryEntries {
                    try historyStore.insert(entry)
                }
                pendingHistoryEntries.removeAll()
            } catch {
                NSLog("Kaskas: Failed to save break history: %@", String(describing: error))
                return
            }
        }
        store.save(state: engine.state)
    }

    private func refreshSnapshot(at now: Date = Date()) {
        sessionSnapshot = engine.snapshot(at: now)
    }
}
