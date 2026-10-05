import Foundation

enum ScheduledBreakKind: String, Codable, Equatable, Sendable {
    case short
    case long
}

struct FocusRun: Codable, Equatable, Sendable {
    var startedAt: Date
    var endsAt: Date
    var nextMicroReminderAt: Date?
    var warningShown: Bool
}

struct BreakRun: Codable, Equatable, Sendable {
    var kind: ScheduledBreakKind
    var startedAt: Date
    var endsAt: Date
}

enum SuspendReason: String, Codable, Equatable, Sendable {
    case manual
    case meeting
    case video
    case idle
    case system
}

enum FrozenRun: Codable, Equatable, Sendable {
    case focus(remaining: TimeInterval, total: TimeInterval, nextMicroReminderIn: TimeInterval?, warningShown: Bool)
    case breakTime(kind: ScheduledBreakKind, remaining: TimeInterval, total: TimeInterval)
}

struct Suspension: Codable, Equatable, Sendable {
    var reason: SuspendReason
    var awaySince: Date
    var frozen: FrozenRun
    // Optional for compatibility with saved sessions predating video protection.
    var videoPending: Bool?
    var meetingPending: Bool

    init(
        reason: SuspendReason,
        awaySince: Date,
        frozen: FrozenRun,
        meetingPending: Bool = false,
        videoPending: Bool? = nil
    ) {
        self.reason = reason
        self.awaySince = awaySince
        self.frozen = frozen
        self.meetingPending = meetingPending
        self.videoPending = videoPending
    }

    var pendingProtectionReason: SuspendReason? {
        meetingPending ? .meeting : (videoPending == true ? .video : nil)
    }
}

enum SessionStatus: Codable, Equatable, Sendable {
    case focusing(FocusRun)
    case onBreak(BreakRun)
    case suspended(Suspension)

    var isPaused: Bool {
        if case .suspended = self { return true }
        return false
    }

    var isManualPaused: Bool {
        if case .suspended(let s) = self { return s.reason == .manual }
        return false
    }

    var isMeetingPaused: Bool {
        if case .suspended(let s) = self { return s.reason == .meeting }
        return false
    }

    var isVideoPaused: Bool {
        if case .suspended(let s) = self { return s.reason == .video }
        return false
    }

    var isProtectionPaused: Bool { isMeetingPaused || isVideoPaused }

    var isIdlePaused: Bool {
        if case .suspended(let s) = self { return s.reason == .idle }
        return false
    }

    var isSystemPaused: Bool {
        if case .suspended(let s) = self { return s.reason == .system }
        return false
    }

    var phase: SessionPhase {
        switch self {
        case .focusing:
            return .focusing
        case .onBreak:
            return .onBreak
        case .suspended(let s):
            switch s.frozen {
            case .focus: return .focusing
            case .breakTime: return .onBreak
            }
        }
    }

    var activityKind: ActivityKind {
        switch self {
        case .focusing:
            return .studying
        case .onBreak:
            return .breakTime
        case .suspended(let s):
            switch s.reason {
            case .system, .idle:
                return .computerInactive
            case .manual, .video:
                return .kaskasPaused
            case .meeting:
                return .meeting
            }
        }
    }

    func freeze(at now: Date) -> FrozenRun {
        switch self {
        case .focusing(let run):
            let total = max(1, run.endsAt.timeIntervalSince(run.startedAt))
            let remaining = max(0, run.endsAt.timeIntervalSince(now))
            let nextReminderIn = run.nextMicroReminderAt.map { max(0, $0.timeIntervalSince(now)) }
            return .focus(
                remaining: remaining,
                total: total,
                nextMicroReminderIn: nextReminderIn,
                warningShown: run.warningShown
            )
        case .onBreak(let run):
            let total = max(1, run.endsAt.timeIntervalSince(run.startedAt))
            let remaining = max(0, run.endsAt.timeIntervalSince(now))
            return .breakTime(kind: run.kind, remaining: remaining, total: total)
        case .suspended(let suspension):
            return suspension.frozen
        }
    }
}
