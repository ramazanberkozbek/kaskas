import Foundation

struct SessionState: Codable, Equatable, Sendable {
    let status: SessionStatus
    let activeConfiguration: FocusConfiguration
    let completedBreaks: Int
    let completedBreaksDay: Date?
    let consecutiveSkippedBreaks: Int
    let scheduledBreakCount: Int

    init(
        status: SessionStatus,
        activeConfiguration: FocusConfiguration,
        completedBreaks: Int = 0,
        completedBreaksDay: Date? = nil,
        consecutiveSkippedBreaks: Int = 0,
        scheduledBreakCount: Int = 0
    ) {
        self.status = status
        self.activeConfiguration = activeConfiguration
        self.completedBreaks = completedBreaks
        self.completedBreaksDay = completedBreaksDay
        self.consecutiveSkippedBreaks = consecutiveSkippedBreaks
        self.scheduledBreakCount = scheduledBreakCount
    }

    var idlePauseStartedAt: Date? {
        if case .suspended(let s) = status, s.reason == .idle {
            return s.awaySince
        }
        return nil
    }

    var systemPauseStartedAt: Date? {
        if case .suspended(let s) = status, s.reason == .system {
            return s.awaySince
        }
        return nil
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
}
