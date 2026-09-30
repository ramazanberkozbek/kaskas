import Foundation

enum ActivityKind: String, Codable, CaseIterable, Sendable {
    case studying
    case breakTime
    case computerInactive
    case kaskasPaused
    case meeting
}

struct ActivityInterval: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let kind: ActivityKind
    let startedAt: Date
    let endedAt: Date

    // The end changes while an active interval is being recorded; the start does not.
    var sessionKey: String { "\(kind.rawValue)-\(startedAt.timeIntervalSinceReferenceDate.bitPattern)" }

    nonisolated init(kind: ActivityKind, startedAt: Date, endedAt: Date) {
        self.kind = kind
        self.startedAt = startedAt
        self.endedAt = max(startedAt, endedAt)
        id = "\(kind.rawValue)-\(startedAt.timeIntervalSinceReferenceDate.bitPattern)-\(self.endedAt.timeIntervalSinceReferenceDate.bitPattern)"
    }
}

struct SessionAnnotation: Codable, Equatable, Sendable {
    var category = ""
    var note = ""
}

struct ActivityCursor: Codable, Equatable, Sendable {
    let kind: ActivityKind
    let startedAt: Date
    let checkpointAt: Date
}

struct ActivityJournal: Codable, Equatable, Sendable {
    var cursor: ActivityCursor?
    var pending: [ActivityInterval]

    static let empty = Self(cursor: nil, pending: [])
}
