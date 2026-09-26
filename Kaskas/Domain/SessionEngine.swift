import Foundation

struct SessionEngine: Sendable {
    static let breakWarningLeadTime: TimeInterval = 20
    static let meaningfulBreakDuration: TimeInterval = 60
    static let meetingResumeDelay: TimeInterval = 60
    static let systemResumeGrace: TimeInterval = 60

    private(set) var configuration: FocusConfiguration
    private(set) var activeConfiguration: FocusConfiguration
    private(set) var session: FocusSession
    private(set) var hasShownBreakWarning = false
    private(set) var completedBreaks = 0
    private(set) var completedBreaksDay: Date?
    private(set) var consecutiveSkippedBreaks = 0
    private(set) var scheduledBreakCount = 0
    private(set) var meetingPauseStartedAt: Date?
    private(set) var manualPauseStartedAt: Date?
    private(set) var systemPauseStartedAt: Date?

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
        consecutiveSkippedBreaks = restoredState.consecutiveSkippedBreaks
        scheduledBreakCount = restoredState.scheduledBreakCount
        meetingPauseStartedAt = restoredState.meetingPauseStartedAt
        manualPauseStartedAt = restoredState.manualPauseStartedAt
        systemPauseStartedAt = restoredState.systemPauseStartedAt
    }

    var state: SessionState {
        SessionState(
            session: session,
            activeConfiguration: activeConfiguration,
            hasShownBreakWarning: hasShownBreakWarning,
            completedBreaks: completedBreaks,
            completedBreaksDay: completedBreaksDay,
            consecutiveSkippedBreaks: consecutiveSkippedBreaks,
            scheduledBreakCount: scheduledBreakCount,
            meetingPauseStartedAt: meetingPauseStartedAt,
            manualPauseStartedAt: manualPauseStartedAt,
            systemPauseStartedAt: systemPauseStartedAt
        )
    }

    func breaksTakenToday(at now: Date = Date()) -> Int {
        guard let completedBreaksDay,
              Calendar.current.isDate(completedBreaksDay, inSameDayAs: now) else {
            return 0
        }
        return completedBreaks
    }

    var nextEventDate: Date? {
        if meetingPauseStartedAt != nil || manualPauseStartedAt != nil || systemPauseStartedAt != nil { return nil }
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
        let effectiveNow = [meetingPauseStartedAt, manualPauseStartedAt, systemPauseStartedAt]
            .compactMap { $0 }
            .reduce(now, min)
        let remaining = max(0, session.endsAt.timeIntervalSince(effectiveNow))
        let elapsed = totalDuration - remaining
        let nextBreakKind: ScheduledBreakKind? = session.phase == .focusing
            ? (activeConfiguration.longBreakEnabled
                && (scheduledBreakCount + 1) % activeConfiguration.longBreakFrequency == 0
                ? .long : .short)
            : nil

        return SessionSnapshot(
            phase: session.phase,
            startedAt: session.startedAt,
            endsAt: session.endsAt,
            nextMicroReminderAt: session.nextMicroReminderAt,
            remaining: remaining,
            progress: min(max(elapsed / totalDuration, 0), 1),
            nextBreakKind: nextBreakKind,
            meetingPauseStartedAt: meetingPauseStartedAt,
            manualPauseStartedAt: manualPauseStartedAt
        )
    }

    mutating func prepareForLaunch(at now: Date = Date()) {
        if meetingPauseStartedAt != nil || manualPauseStartedAt != nil || systemPauseStartedAt != nil { return }
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
            if manualPauseStartedAt != nil { manualPauseStartedAt = now }
        }
        self.configuration = configuration
    }

    mutating func process(at now: Date = Date()) -> [SessionEvent] {
        if meetingPauseStartedAt != nil || manualPauseStartedAt != nil || systemPauseStartedAt != nil { return [] }
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

    mutating func startBreak(at now: Date = Date(), scheduled: Bool = true) {
        meetingPauseStartedAt = nil
        hasShownBreakWarning = false
        if scheduled && activeConfiguration.longBreakEnabled { scheduledBreakCount += 1 }
        let isLongBreak = scheduled
            && activeConfiguration.longBreakEnabled
            && scheduledBreakCount % activeConfiguration.longBreakFrequency == 0
        let duration = isLongBreak
            ? activeConfiguration.longBreakDuration
            : activeConfiguration.breakDuration
        session = FocusSession(
            phase: .onBreak,
            startedAt: now,
            endsAt: now.addingTimeInterval(duration),
            nextMicroReminderAt: nil
        )
    }

    mutating func completeBreak(at now: Date = Date()) {
        if session.phase == .onBreak {
            recordCompletedBreak(at: now)
        }
        startFocus(at: now)
    }

    @discardableResult
    mutating func skipBreak(at now: Date = Date()) -> Bool {
        if session.phase == .onBreak,
           now.timeIntervalSince(session.startedAt) >= Self.meaningfulBreakDuration {
            consecutiveSkippedBreaks = 0
            startFocus(at: now)
            return false
        }
        consecutiveSkippedBreaks += 1
        startFocus(at: now)
        return consecutiveSkippedBreaks % 3 == 0
    }

    private mutating func recordCompletedBreak(at now: Date) {
        completedBreaks = breaksTakenToday(at: now) + 1
        completedBreaksDay = now
        consecutiveSkippedBreaks = 0
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
        meetingPauseStartedAt = nil
        hasShownBreakWarning = false
        session = FocusSession(
            phase: .focusing,
            startedAt: now,
            endsAt: now.addingTimeInterval(activeConfiguration.snoozeDuration),
            nextMicroReminderAt: nil
        )
    }

    private mutating func startFocus(at now: Date) {
        meetingPauseStartedAt = nil
        hasShownBreakWarning = false
        if activeConfiguration.longBreakEnabled != configuration.longBreakEnabled
            || activeConfiguration.longBreakFrequency != configuration.longBreakFrequency {
            scheduledBreakCount = 0
        }
        activeConfiguration = configuration
        session = Self.makeFocusSession(configuration: activeConfiguration, startingAt: now)
    }

    mutating func beginMeetingPause(at now: Date) {
        guard meetingPauseStartedAt == nil, manualPauseStartedAt == nil, systemPauseStartedAt == nil,
              session.phase == .focusing else { return }
        meetingPauseStartedAt = now
        hasShownBreakWarning = false
    }

    mutating func endMeetingPause(at now: Date) {
        guard systemPauseStartedAt == nil else { return }
        guard let startedAt = meetingPauseStartedAt else { return }
        meetingPauseStartedAt = nil
        let shift = max(0, now.timeIntervalSince(startedAt)) + Self.meetingResumeDelay
        shiftDeadlines(by: shift)
        skipPastReminders(at: now)
    }

    mutating func beginManualPause(at now: Date) {
        guard manualPauseStartedAt == nil, systemPauseStartedAt == nil else { return }
        if meetingPauseStartedAt != nil { endMeetingPause(at: now) }
        manualPauseStartedAt = now
        hasShownBreakWarning = false
    }

    mutating func endManualPause(at now: Date) {
        guard systemPauseStartedAt == nil, let startedAt = manualPauseStartedAt else { return }
        manualPauseStartedAt = nil
        shiftDeadlines(by: max(0, now.timeIntervalSince(startedAt)))
        skipPastReminders(at: now)
    }

    mutating func beginSystemPause(at now: Date) {
        guard systemPauseStartedAt == nil else { return }
        systemPauseStartedAt = now
        hasShownBreakWarning = false
    }

    mutating func endSystemPause(at now: Date, meetingActive: Bool) {
        guard let startedAt = systemPauseStartedAt else { return }
        systemPauseStartedAt = nil

        if manualPauseStartedAt != nil { return }

        if meetingPauseStartedAt != nil {
            if !meetingActive { endMeetingPause(at: now) }
            return
        }

        let remainingAtPause = session.endsAt.timeIntervalSince(startedAt)
        var shift = max(0, now.timeIntervalSince(startedAt))
        if session.phase == .focusing {
            // Give the user time to settle before a warning or full-screen break.
            shift += max(0, Self.systemResumeGrace - remainingAtPause)
        }
        shiftDeadlines(by: shift)
        skipPastReminders(at: now)
        if meetingActive { beginMeetingPause(at: now) }
    }

    private mutating func shiftDeadlines(by duration: TimeInterval) {
        session.startedAt = session.startedAt.addingTimeInterval(duration)
        session.endsAt = session.endsAt.addingTimeInterval(duration)
        session.nextMicroReminderAt = session.nextMicroReminderAt?.addingTimeInterval(duration)
    }

    private mutating func skipPastReminders(at now: Date) {
        guard let reminderAt = session.nextMicroReminderAt, reminderAt <= now else { return }
        session.nextMicroReminderAt = nextFutureMicroReminder(
            after: reminderAt,
            relativeTo: now,
            focusEndsAt: session.endsAt
        )
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
