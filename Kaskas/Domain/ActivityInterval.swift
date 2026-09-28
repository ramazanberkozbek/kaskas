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

    nonisolated init(kind: ActivityKind, startedAt: Date, endedAt: Date) {
        self.kind = kind
        self.startedAt = startedAt
        self.endedAt = max(startedAt, endedAt)
        id = "\(kind.rawValue)-\(startedAt.timeIntervalSinceReferenceDate.bitPattern)-\(self.endedAt.timeIntervalSinceReferenceDate.bitPattern)"
    }
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
