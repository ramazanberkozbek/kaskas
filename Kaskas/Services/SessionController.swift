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
    @ObservationIgnored private var hasStarted = false

    init(
        store: SessionStore = SessionStore(),
        scheduler: SessionScheduler = SessionScheduler(),
        microReminderPresenter: MicroReminderPresenter = MicroReminderPresenter(),
        breakWarningPresenter: BreakWarningPresenter = BreakWarningPresenter(),
        breakPresenter: BreakPresenter = BreakPresenter(),
        now: Date = Date()
    ) {
        let configuration = store.loadConfiguration()
        self.configuration = configuration
        self.store = store
        self.scheduler = scheduler
        self.microReminderPresenter = microReminderPresenter
        self.breakWarningPresenter = breakWarningPresenter
        self.breakPresenter = breakPresenter

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
        reconcile()
    }

    func stop() {
        scheduler.cancel()
        microReminderPresenter.dismiss()
        breakWarningPresenter.dismiss()
        breakPresenter.dismiss()
        persistSession()
    }

    func reconcile(at now: Date = Date()) {
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

    func updateConfiguration(_ configuration: FocusConfiguration) {
        self.configuration = configuration
        engine.updateConfiguration(configuration)
        store.save(configuration: configuration)
        persistSession()
    }

    func startBreakNow() {
        let now = Date()
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
        NSApp.activate(ignoringOtherApps: true)
        let selector = Selector(("showSettingsWindow:"))
        NSApp.sendAction(selector, to: nil as AnyObject?, from: nil as AnyObject?)
    }

    func previewBreak() {
        breakPresenter.show(
            endsAt: Date.now.addingTimeInterval(20),
            configuration: configuration,
            isPreview: true,
            onSnooze: { [weak self] in
                self?.snoozeBreak()
            },
            onSkip: { [weak self] in
                self?.completeBreak()
            },
            onLockScreen: {
                SystemAction.lockScreen()
            },
            onOpenSettings: { [weak self] in
                self?.openSettings()
            }
        )
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
            microReminderPresenter.show()

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
        engine.completeBreak(at: now)
        breakWarningPresenter.dismiss()
        refreshSnapshot(at: now)
        persistSession()
        scheduleNextEvent()
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
                self?.completeBreak()
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

    private func persistSession() {
        store.save(state: engine.state)
    }

    private func refreshSnapshot(at now: Date = Date()) {
        sessionSnapshot = engine.snapshot(at: now)
    }
}
