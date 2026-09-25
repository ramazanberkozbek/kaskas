import Foundation

struct SessionEngine: Sendable {
    static let breakWarningLeadTime: TimeInterval = 20

    private(set) var configuration: FocusConfiguration
    private(set) var activeConfiguration: FocusConfiguration
    private(set) var session: FocusSession
    private(set) var hasShownBreakWarning = false
    private(set) var completedBreaks = 0
    private(set) var completedBreaksDay: Date?

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
        hasShownBreakWarning = restoredState.hasShownBreakWarning
        completedBreaks = restoredState.completedBreaks
        completedBreaksDay = restoredState.completedBreaksDay
    }

    var state: SessionState {
        SessionState(
            session: session,
            activeConfiguration: activeConfiguration,
            hasShownBreakWarning: hasShownBreakWarning,
            completedBreaks: completedBreaks,
            completedBreaksDay: completedBreaksDay
        )
    }

    func breaksTakenToday(at now: Date = Date()) -> Int {
        guard let completedBreaksDay,
              Calendar.current.isDate(completedBreaksDay, inSameDayAs: now) else {
            return 0
        }
        return completedBreaks
    }

    var nextEventDate: Date {
        switch session.phase {
        case .focusing:
            var nextDate = session.endsAt
            if let microReminderAt = session.nextMicroReminderAt {
                nextDate = min(nextDate, microReminderAt)
            }
            if !hasShownBreakWarning {
                let warningAt = max(
                    session.startedAt,
                    session.endsAt.addingTimeInterval(-Self.breakWarningLeadTime)
                )
                nextDate = min(nextDate, warningAt)
            }
            return nextDate

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

    mutating func prepareForLaunch(at now: Date = Date()) {
        // A break or its warning must not take over the screen as the app opens.
        // Keep a focus session only when there is enough time before its warning.
        if session.phase == .onBreak ||
            session.endsAt.timeIntervalSince(now) <= Self.breakWarningLeadTime ||
            hasShownBreakWarning {
            startFocus(at: now)
            return
        }

        if let reminderAt = session.nextMicroReminderAt, reminderAt <= now {
            session.nextMicroReminderAt = nextFutureMicroReminder(
                after: reminderAt,
                relativeTo: now,
                focusEndsAt: session.endsAt
            )
        }
    }

    mutating func updateConfiguration(
        _ configuration: FocusConfiguration,
        at now: Date = Date()
    ) {
        if session.phase == .focusing,
           configuration.focusDuration != self.configuration.focusDuration {
            activeConfiguration.focusDuration = configuration.focusDuration
            session = Self.makeFocusSession(configuration: activeConfiguration, startingAt: now)
            hasShownBreakWarning = false
        }
        self.configuration = configuration
    }

    mutating func process(at now: Date = Date()) -> [SessionEvent] {
        switch session.phase {
        case .focusing:
            if now >= session.endsAt {
                startBreak(at: now)
                return [.fullBreakDue]
            }

            let warningAt = max(
                session.startedAt,
                session.endsAt.addingTimeInterval(-Self.breakWarningLeadTime)
            )
            if !hasShownBreakWarning, now >= warningAt {
                hasShownBreakWarning = true
                session.nextMicroReminderAt = session.nextMicroReminderAt.flatMap { reminderAt in
                    now >= reminderAt
                        ? nextFutureMicroReminder(
                            after: reminderAt,
                            relativeTo: now,
                            focusEndsAt: session.endsAt
                        )
                        : reminderAt
                }
                return [.breakApproaching]
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

            recordCompletedBreak(at: now)
            startFocus(at: now)
            return [.breakEnded]
        }
    }

    mutating func startBreak(at now: Date = Date()) {
        hasShownBreakWarning = false
        session = FocusSession(
            phase: .onBreak,
            startedAt: now,
            endsAt: now.addingTimeInterval(activeConfiguration.breakDuration),
            nextMicroReminderAt: nil
        )
    }

    mutating func completeBreak(at now: Date = Date()) {
        if session.phase == .onBreak {
            recordCompletedBreak(at: now)
        }
        startFocus(at: now)
    }

    private mutating func recordCompletedBreak(at now: Date) {
        completedBreaks = breaksTakenToday(at: now) + 1
        completedBreaksDay = now
    }

    mutating func snooze() {
        guard session.phase == .focusing else {
            return
        }

        session.endsAt = session.endsAt.addingTimeInterval(activeConfiguration.snoozeDuration)
        hasShownBreakWarning = false
    }

    mutating func postponeBreak(by duration: TimeInterval) {
        guard session.phase == .focusing else { return }
        session.endsAt = session.endsAt.addingTimeInterval(max(1, duration))
        hasShownBreakWarning = duration <= Self.breakWarningLeadTime
    }

    mutating func snoozeBreak(at now: Date = Date()) {
        hasShownBreakWarning = false
        session = FocusSession(
            phase: .focusing,
            startedAt: now,
            endsAt: now.addingTimeInterval(activeConfiguration.snoozeDuration),
            nextMicroReminderAt: nil
        )
    }

    private mutating func startFocus(at now: Date) {
        hasShownBreakWarning = false
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
