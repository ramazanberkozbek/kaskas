import Foundation

struct SessionSnapshot: Equatable, Sendable {
    let phase: SessionPhase
    let startedAt: Date
    let endsAt: Date
    let nextMicroReminderAt: Date?
    let remaining: TimeInterval
    let progress: Double
    let meetingPauseStartedAt: Date?
}
