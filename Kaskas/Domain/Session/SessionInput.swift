import Foundation

enum SystemCause: String, Codable, Equatable, Sendable {
    case sleep
    case lock
    case quit
}

enum SessionInput: Equatable, Sendable {
    case launch(meetingActive: Bool)
    case tick
    case toggleManualPause
    case setManualPause(active: Bool)
    case setMeeting(active: Bool)
    case beginIdle(startedAt: Date)
    case idleReturned(returnedAt: Date)
    case resolveIdle(acceptedAsBreak: Bool, returnedAt: Date)
    case systemSuspended(cause: SystemCause)
    case systemResumed(meetingActive: Bool)
    case startBreak(scheduled: Bool)
    case completeBreak
    case skipBreak
    case snooze
    case snoozeBreak
    case postponeBreak(by: TimeInterval)
    case updateConfiguration(FocusConfiguration)
}

extension SessionInput {
    static var launch: SessionInput { .launch(meetingActive: false) }
    static var startBreakNow: SessionInput { .startBreak(scheduled: false) }
    static var sleep: SessionInput { .systemSuspended(cause: .sleep) }
    static var lock: SessionInput { .systemSuspended(cause: .lock) }
    static var quit: SessionInput { .systemSuspended(cause: .quit) }
    static var systemResumed: SessionInput { .systemResumed(meetingActive: false) }
}
