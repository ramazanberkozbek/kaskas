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
    @ObservationIgnored private let breakPresenter: BreakPresenter
    @ObservationIgnored private var hasStarted = false

    init(
        store: SessionStore = SessionStore(),
        scheduler: SessionScheduler = SessionScheduler(),
        microReminderPresenter: MicroReminderPresenter = MicroReminderPresenter(),
        breakPresenter: BreakPresenter = BreakPresenter(),
        now: Date = Date()
    ) {
        let configuration = store.loadConfiguration()
        self.configuration = configuration
        self.store = store
        self.scheduler = scheduler
        self.microReminderPresenter = microReminderPresenter
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
        engine.startBreak(at: now)
        refreshSnapshot(at: now)
        persistSession()
        presentCurrentBreak()
        scheduleNextEvent()
    }

    func snooze() {
        engine.snooze()
        refreshSnapshot()
        persistSession()
        scheduleNextEvent()
    }

    func completeBreak() {
        let now = Date()
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

        case .fullBreakDue:
            microReminderPresenter.dismiss()
            presentCurrentBreak()

        case .breakEnded:
            breakPresenter.dismiss()
        }
    }

    private func presentCurrentBreak() {
        breakPresenter.show(endsAt: engine.session.endsAt) { [weak self] in
            self?.completeBreak()
        }
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
