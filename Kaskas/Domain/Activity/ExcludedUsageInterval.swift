import Foundation

/// An excluded visit contains timing only, never application identity.
nonisolated struct ExcludedUsageInterval: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let startedAt: Date
    let endedAt: Date
}

nonisolated struct ExcludedUsageCursor: Codable, Equatable, Sendable {
    let id: UUID
    let startedAt: Date
    var checkpointAt: Date

    func interval(endingAt end: Date) -> ExcludedUsageInterval {
        .init(id: id, startedAt: startedAt, endedAt: max(startedAt, end))
    }
}

nonisolated struct ExcludedUsageJournal: Codable, Equatable, Sendable {
    var cursor: ExcludedUsageCursor?
    var pending: [ExcludedUsageInterval] = []
}
