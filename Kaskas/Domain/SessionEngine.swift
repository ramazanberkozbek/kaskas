import Foundation

struct SessionEngine: Sendable {
    private(set) var configuration: FocusConfiguration
    private(set) var activeConfiguration: FocusConfiguration
    private(set) var session: FocusSession

    init(
        configuration: FocusConfiguration = FocusConfiguration(),
        now: Date = Date()
    ) {
        self.configuration = configuration
        activeConfiguration = configuration
        session = Self.makeFocusSession(configuration: configuration, startingAt: now)
    }

    init(configuration: FocusConfiguration, restoredState: SessionState) {
        self.configuration = configuration
        activeConfiguration = restoredState.activeConfiguration
        session = restoredState.session
    }

    var state: SessionState {
        SessionState(
            session: session,
            activeConfiguration: activeConfiguration
        )
    }

    var nextEventDate: Date {
        switch session.phase {
        case .focusing:
            guard let microReminderAt = session.nextMicroReminderAt else {
                return session.endsAt
            }
            return min(microReminderAt, session.endsAt)

        case .onBreak:
            return session.endsAt
        }
    }

    func snapshot(at now: Date = Date()) -> SessionSnapshot {
        let totalDuration = max(1, session.endsAt.timeIntervalSince(session.startedAt))
        let remaining = max(0, session.endsAt.timeIntervalSince(now))
        let elapsed = totalDuration - remaining

        return SessionSnapshot(
            phase: session.phase,
            startedAt: session.startedAt,
            endsAt: session.endsAt,
            nextMicroReminderAt: session.nextMicroReminderAt,
            remaining: remaining,
            progress: min(max(elapsed / totalDuration, 0), 1)
        )
    }

    mutating func updateConfiguration(_ configuration: FocusConfiguration) {
        self.configuration = configuration
    }

    mutating func process(at now: Date = Date()) -> [SessionEvent] {
        switch session.phase {
        case .focusing:
            if now >= session.endsAt {
                startBreak(at: now)
                return [.fullBreakDue]
            }

            guard let reminderAt = session.nextMicroReminderAt, now >= reminderAt else {
                return []
            }

            session.nextMicroReminderAt = nextFutureMicroReminder(
                after: reminderAt,
                relativeTo: now,
                focusEndsAt: session.endsAt
            )
            return [.microReminderDue]

        case .onBreak:
            guard now >= session.endsAt else {
                return []
            }

            startFocus(at: now)
            return [.breakEnded]
        }
    }

    mutating func startBreak(at now: Date = Date()) {
        session = FocusSession(
            phase: .onBreak,
            startedAt: now,
            endsAt: now.addingTimeInterval(activeConfiguration.breakDuration),
            nextMicroReminderAt: nil
        )
    }

    mutating func completeBreak(at now: Date = Date()) {
        startFocus(at: now)
    }

    mutating func snooze() {
        guard session.phase == .focusing else {
            return
        }

        session.endsAt = session.endsAt.addingTimeInterval(activeConfiguration.snoozeDuration)
    }

    mutating func snoozeBreak(at now: Date = Date()) {
        session = FocusSession(
            phase: .focusing,
            startedAt: now,
            endsAt: now.addingTimeInterval(activeConfiguration.snoozeDuration),
            nextMicroReminderAt: nil
        )
    }

    private mutating func startFocus(at now: Date) {
        activeConfiguration = configuration
        session = Self.makeFocusSession(configuration: activeConfiguration, startingAt: now)
    }

    private func nextFutureMicroReminder(
        after reminderAt: Date,
        relativeTo now: Date,
        focusEndsAt: Date
    ) -> Date? {
        let elapsedIntervals = floor(
            now.timeIntervalSince(reminderAt) / activeConfiguration.microReminderInterval
        ) + 1
        let nextReminderAt = reminderAt.addingTimeInterval(
            elapsedIntervals * activeConfiguration.microReminderInterval
        )

        return nextReminderAt < focusEndsAt ? nextReminderAt : nil
    }

    private static func makeFocusSession(
        configuration: FocusConfiguration,
        startingAt startDate: Date
    ) -> FocusSession {
        let endsAt = startDate.addingTimeInterval(configuration.focusDuration)
        let firstReminderAt = startDate.addingTimeInterval(configuration.microReminderInterval)

        return FocusSession(
            phase: .focusing,
            startedAt: startDate,
            endsAt: endsAt,
            nextMicroReminderAt: firstReminderAt < endsAt ? firstReminderAt : nil
        )
    }
}
