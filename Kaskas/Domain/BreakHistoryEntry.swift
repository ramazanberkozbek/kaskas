import Foundation

struct BreakHistoryEntry: Codable, Equatable, Sendable {
    enum Outcome: String, Codable, Sendable {
        case completed
        case skipped
    }

    enum Source: String, Codable, Sendable {
        case scheduled
        case manual
        case smartPause
    }

    let id: String
    let occurredAt: Date
    let startedAt: Date?
    let focusStartedAt: Date?
    let focusedDuration: TimeInterval?
    let outcome: Outcome
    let source: Source

    var isSessionBoundary: Bool {
        startedAt != nil && source != .smartPause
    }

    static func transition(
        from session: FocusSession,
        at date: Date,
        outcome: Outcome,
        source: Source
    ) -> Self {
        let startBits = String(session.startedAt.timeIntervalSinceReferenceDate.bitPattern, radix: 16)
        return Self(
            id: "break-\(outcome.rawValue)-\(session.phase.rawValue)-\(startBits)",
            occurredAt: date,
            startedAt: session.phase == .onBreak ? session.startedAt : nil,
            focusStartedAt: session.phase == .focusing ? session.startedAt : nil,
            focusedDuration: nil,
            outcome: outcome,
            source: source
        )
    }

    static func legacySmartPause(_ record: LegacySmartPauseRecord) -> Self {
        let startBits = String(record.focusStartedAt.timeIntervalSinceReferenceDate.bitPattern, radix: 16)
        let stopBits = String(record.focusStoppedAt.timeIntervalSinceReferenceDate.bitPattern, radix: 16)
        let returnBits = String(record.returnedAt.timeIntervalSinceReferenceDate.bitPattern, radix: 16)
        return Self(
            id: "smart-pause-\(startBits)-\(stopBits)-\(returnBits)",
            occurredAt: record.returnedAt,
            startedAt: nil,
            focusStartedAt: record.focusStartedAt,
            focusedDuration: record.focusedDuration,
            outcome: .completed,
            source: .smartPause
        )
    }

    static func idleBreak(from session: FocusSession, startedAt: Date, returnedAt: Date) -> Self {
        let focusBits = String(session.startedAt.timeIntervalSinceReferenceDate.bitPattern, radix: 16)
        let idleBits = String(startedAt.timeIntervalSinceReferenceDate.bitPattern, radix: 16)
        return Self(
            id: "smart-pause-\(focusBits)-\(idleBits)",
            occurredAt: returnedAt,
            startedAt: startedAt,
            focusStartedAt: session.startedAt,
            focusedDuration: max(0, startedAt.timeIntervalSince(session.startedAt)),
            outcome: .completed,
            source: .smartPause
        )
    }
}

struct LegacySmartPauseRecord: Decodable, Sendable {
    let focusStartedAt: Date
    let focusStoppedAt: Date
    let returnedAt: Date
    let focusedDuration: TimeInterval
}
