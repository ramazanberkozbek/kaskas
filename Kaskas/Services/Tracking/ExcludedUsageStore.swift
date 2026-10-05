import Foundation
import SwiftData

@Model
nonisolated final class ExcludedUsageRecord {
    @Attribute(.unique) var recordID: UUID
    var startedAt: Date
    var endedAt: Date

    init(_ interval: ExcludedUsageInterval) {
        recordID = interval.id
        startedAt = interval.startedAt
        endedAt = interval.endedAt
    }

    var interval: ExcludedUsageInterval {
        .init(id: recordID, startedAt: startedAt, endedAt: endedAt)
    }
}

@MainActor
protocol ExcludedUsageRecording {
    func insertBatch(_ values: [ExcludedUsageInterval]) async throws
    func intervals(from start: Date, to end: Date) throws -> [ExcludedUsageInterval]
    func intervalsAsync(from start: Date, to end: Date) async throws -> [ExcludedUsageInterval]
}

extension ExcludedUsageRecording {
    func intervalsAsync(from start: Date, to end: Date) async throws -> [ExcludedUsageInterval] {
        try intervals(from: start, to: end)
    }
}

@MainActor
final class ExcludedUsageStore: ExcludedUsageRecording {
    private let container: ModelContainer
    private let context: ModelContext
    private let writer: HistoryWriteWorker

    init(container: ModelContainer) {
        self.container = container
        context = ModelContext(container)
        writer = HistoryWriteWorker(container: container)
    }

    func insertBatch(_ values: [ExcludedUsageInterval]) async throws {
        try await writer.insert(values)
    }

    func intervals(from start: Date, to end: Date) throws -> [ExcludedUsageInterval] {
        let query = FetchDescriptor<ExcludedUsageRecord>(predicate: #Predicate { $0.startedAt < end && $0.endedAt > start },
                                                        sortBy: [SortDescriptor(\.startedAt)])
        return try context.fetch(query).map(\.interval)
    }

    func intervalsAsync(from start: Date, to end: Date) async throws -> [ExcludedUsageInterval] {
        try await HistoryReadWorker.excludedIntervals(container: container, from: start, to: end)
    }
}
