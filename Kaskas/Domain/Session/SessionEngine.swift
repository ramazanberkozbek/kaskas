import Foundation

struct SessionEngine: Sendable {
    static let meaningfulBreakDuration: TimeInterval = 60
    static let meetingResumeDelay: TimeInterval = 60
    static let systemResumeGrace: TimeInterval = 60

    var configuration: FocusConfiguration
    var activeConfiguration: FocusConfiguration
    var status: SessionStatus
    var completedBreaks = 0
    var completedBreaksDay: Date?
    var consecutiveSkippedBreaks = 0
    var scheduledBreakCount = 0
    var ignoresProtectionForCycle = false

    // MARK: - Initialization

    init(
        configuration: FocusConfiguration = FocusConfiguration(),
        now: Date = Date()
    ) {
        self.configuration = configuration
        activeConfiguration = configuration
        status = .focusing(Self.makeFocusRun(
            duration: configuration.focusDuration,
            microReminderInterval: configuration.microReminderInterval,
            at: now
        ))
    }

    init(
        configuration: FocusConfiguration,
        restoredState: SessionState,
        lastActiveAt: Date? = nil,
        now: Date = Date()
    ) {
        self.configuration = configuration
        activeConfiguration = restoredState.activeConfiguration
        activeConfiguration.microReminderInterval = configuration.microReminderInterval
        completedBreaks = restoredState.completedBreaks
        completedBreaksDay = restoredState.completedBreaksDay
        consecutiveSkippedBreaks = restoredState.consecutiveSkippedBreaks
        scheduledBreakCount = restoredState.scheduledBreakCount

        var resolvedStatus = restoredState.status
        if case .suspended(let s) = resolvedStatus, s.reason == .idle || s.reason == .typing {
            let resumeAt = lastActiveAt ?? now
            if case .focus(let rem, let tot, _, let w) = s.frozen {
                let resumeGrace = max(0, Self.systemResumeGrace - rem)
                let endsAt = resumeAt.addingTimeInterval(rem + resumeGrace)
                let startedAt = endsAt.addingTimeInterval(-tot)
                let warningShown = resumeGrace > 0 ? false : w
                resolvedStatus = .focusing(FocusRun(
                    startedAt: startedAt, endsAt: endsAt, nextMicroReminderAt: nil, warningShown: warningShown
                ))
            } else if case .breakTime(let k, let rem, let tot) = s.frozen {
                let endsAt = resumeAt.addingTimeInterval(rem)
                let startedAt = endsAt.addingTimeInterval(-tot)
                resolvedStatus = .onBreak(BreakRun(kind: k, startedAt: startedAt, endsAt: endsAt))
            }
        }

        if case .suspended = resolvedStatus {
            self.status = resolvedStatus
        } else if let lastActiveAt, lastActiveAt <= now {
            let frozen = resolvedStatus.freeze(at: lastActiveAt)
            self.status = .suspended(Suspension(reason: .system, awaySince: lastActiveAt, frozen: frozen))
        } else {
            self.status = resolvedStatus
        }
    }

    // MARK: - State & Query Properties

    var state: SessionState {
        SessionState(
            status: status,
            activeConfiguration: activeConfiguration,
            completedBreaks: completedBreaks,
            completedBreaksDay: completedBreaksDay,
            consecutiveSkippedBreaks: consecutiveSkippedBreaks,
            scheduledBreakCount: scheduledBreakCount
        )
    }

    var manualPauseStartedAt: Date? {
        if case .suspended(let s) = status, s.reason == .manual { return s.awaySince }
        return nil
    }

    var meetingPauseStartedAt: Date? {
        if case .suspended(let s) = status, s.reason == .meeting { return s.awaySince }
        return nil
    }

    var systemPauseStartedAt: Date? {
        if case .suspended(let s) = status, s.reason == .system { return s.awaySince }
        return nil
    }

    var idlePauseStartedAt: Date? {
        if case .suspended(let s) = status, s.reason == .idle { return s.awaySince }
        return nil
    }

    var hasShownBreakWarning: Bool {
        switch status {
        case .focusing(let run):
            return run.warningShown
        case .suspended(let s):
            if case .focus(_, _, _, let warningShown) = s.frozen { return warningShown }
            return false
        case .onBreak:
            return false
        }
    }

    func currentActivityKind(at now: Date = Date()) -> ActivityKind {
        status.activityKind
    }

    var session: FocusSession {
        switch status {
        case .focusing(let run):
            return FocusSession(
                phase: .focusing,
                startedAt: run.startedAt,
                endsAt: run.endsAt,
                nextMicroReminderAt: run.nextMicroReminderAt
            )
        case .onBreak(let run):
            return FocusSession(
                phase: .onBreak,
                startedAt: run.startedAt,
                endsAt: run.endsAt,
                nextMicroReminderAt: nil
            )
        case .suspended(let suspension):
            switch suspension.frozen {
            case .focus(let remaining, let total, let reminderIn, _):
                let endsAt = suspension.awaySince.addingTimeInterval(remaining)
                let startedAt = endsAt.addingTimeInterval(-total)
                let reminderAt = reminderIn.map { suspension.awaySince.addingTimeInterval($0) }
                return FocusSession(
                    phase: .focusing,
                    startedAt: startedAt,
                    endsAt: endsAt,
                    nextMicroReminderAt: reminderAt
                )
            case .breakTime(_, let remaining, let total):
                let endsAt = suspension.awaySince.addingTimeInterval(remaining)
                let startedAt = endsAt.addingTimeInterval(-total)
                return FocusSession(
                    phase: .onBreak,
                    startedAt: startedAt,
                    endsAt: endsAt,
                    nextMicroReminderAt: nil
                )
            }
        }
    }

    func breaksTakenToday(at now: Date = Date()) -> Int {
        guard let completedBreaksDay,
              Calendar.current.isDate(completedBreaksDay, inSameDayAs: now) else {
            return 0
        }
        return completedBreaks
    }

    var nextEventDate: Date? {
        switch status {
        case .suspended:
            return nil
        case .focusing(let run):
            var nextDate = run.endsAt
            if let microReminderAt = run.nextMicroReminderAt {
                nextDate = min(nextDate, microReminderAt)
            }
            if configuration.breakWarningEnabled, !run.warningShown {
                let warningAt = max(
                    run.startedAt,
                    run.endsAt.addingTimeInterval(-configuration.breakWarningLeadTime)
                )
                nextDate = min(nextDate, warningAt)
            }
            return nextDate
        case .onBreak(let run):
            return run.endsAt
        }
    }

    func snapshot(at now: Date = Date()) -> SessionSnapshot {
        let currentSession = self.session
        let totalDuration: TimeInterval
        let remaining: TimeInterval

        switch status {
        case .focusing, .onBreak:
            totalDuration = max(1, currentSession.endsAt.timeIntervalSince(currentSession.startedAt))
            remaining = max(0, currentSession.endsAt.timeIntervalSince(now))
        case .suspended(let suspension):
            switch suspension.frozen {
            case .focus(let rem, let total, _, _), .breakTime(_, let rem, let total):
                totalDuration = total
                remaining = rem
            }
        }

        let elapsed = totalDuration - remaining
        let isLongBreak = activeConfiguration.longBreakEnabled
            && (scheduledBreakCount + 1) % activeConfiguration.longBreakFrequency == 0
        let nextBreakKind: ScheduledBreakKind? = (status.phase == .focusing) ? (isLongBreak ? .long : .short) : nil

        return SessionSnapshot(
            status: status,
            phase: status.phase,
            startedAt: currentSession.startedAt,
            endsAt: currentSession.endsAt,
            nextMicroReminderAt: currentSession.nextMicroReminderAt,
            remaining: remaining,
            progress: min(max(elapsed / totalDuration, 0), 1),
            nextBreakKind: nextBreakKind
        )
    }

    static func makeFocusRun(
        duration: TimeInterval,
        microReminderInterval: TimeInterval,
        at now: Date
    ) -> FocusRun {
        let endsAt = now.addingTimeInterval(duration)
        let firstReminderAt = now.addingTimeInterval(microReminderInterval)
        return FocusRun(
            startedAt: now,
            endsAt: endsAt,
            nextMicroReminderAt: firstReminderAt < endsAt ? firstReminderAt : nil,
            warningShown: false
        )
    }

    mutating func advanceTime(by duration: TimeInterval) {
        switch status {
        case .focusing(var run):
            run.startedAt = run.startedAt.addingTimeInterval(-duration)
            run.endsAt = run.endsAt.addingTimeInterval(-duration)
            if let reminder = run.nextMicroReminderAt {
                run.nextMicroReminderAt = reminder.addingTimeInterval(-duration)
            }
            status = .focusing(run)
        case .onBreak(var run):
            run.startedAt = run.startedAt.addingTimeInterval(-duration)
            run.endsAt = run.endsAt.addingTimeInterval(-duration)
            status = .onBreak(run)
        case .suspended(var suspension):
            suspension.awaySince = suspension.awaySince.addingTimeInterval(-duration)
            status = .suspended(suspension)
        }
    }

    mutating func advanceDay(at now: Date = Date()) {
        ignoresProtectionForCycle = false
        completedBreaks = 0
        completedBreaksDay = Calendar.current.date(byAdding: .day, value: -1, to: now)
        activeConfiguration = configuration
        status = .focusing(Self.makeFocusRun(
            duration: activeConfiguration.focusDuration,
            microReminderInterval: activeConfiguration.microReminderInterval,
            at: now
        ))
    }

    mutating func resetFocus(at now: Date = Date()) {
        ignoresProtectionForCycle = false
        activeConfiguration = configuration
        status = .focusing(Self.makeFocusRun(
            duration: activeConfiguration.focusDuration,
            microReminderInterval: activeConfiguration.microReminderInterval,
            at: now
        ))
    }
}
