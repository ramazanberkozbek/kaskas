import Foundation

enum ScheduledBreakKind: Equatable, Sendable {
    case short
    case long
}

struct SessionSnapshot: Equatable, Sendable {
    let phase: SessionPhase
    let startedAt: Date
    let endsAt: Date
    let nextMicroReminderAt: Date?
    let remaining: TimeInterval
    let progress: Double
    let nextBreakKind: ScheduledBreakKind?
    let meetingPauseStartedAt: Date?
    let manualPauseStartedAt: Date?
}
