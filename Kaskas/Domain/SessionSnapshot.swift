import Foundation

struct SessionSnapshot: Equatable, Sendable {
    let status: SessionStatus
    let phase: SessionPhase
    let startedAt: Date
    let endsAt: Date
    let nextMicroReminderAt: Date?
    let remaining: TimeInterval
    let progress: Double
    let nextBreakKind: ScheduledBreakKind?

    init(
        status: SessionStatus,
        phase: SessionPhase,
        startedAt: Date,
        endsAt: Date,
        nextMicroReminderAt: Date?,
        remaining: TimeInterval,
        progress: Double,
        nextBreakKind: ScheduledBreakKind?
    ) {
        self.status = status
        self.phase = phase
        self.startedAt = startedAt
        self.endsAt = endsAt
        self.nextMicroReminderAt = nextMicroReminderAt
        self.remaining = remaining
        self.progress = progress
        self.nextBreakKind = nextBreakKind
    }

    var manualPauseStartedAt: Date? {
        if case .suspended(let s) = status, s.reason == .manual {
            return s.awaySince
        }
        return nil
    }

    var meetingPauseStartedAt: Date? {
        if case .suspended(let s) = status, s.reason == .meeting {
            return s.awaySince
        }
        return nil
    }

    var idlePauseStartedAt: Date? {
        if case .suspended(let s) = status, s.reason == .idle {
            return s.awaySince
        }
        return nil
    }
}
