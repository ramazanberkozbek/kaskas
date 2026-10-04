import Foundation
import SwiftData

@Model
nonisolated final class ActivityRecord {
    @Attribute(.unique) var recordID: String
    var kind: String
    var startedAt: Date
    var endedAt: Date

    init(_ interval: ActivityInterval) {
        recordID = interval.id
        kind = interval.kind.rawValue
        startedAt = interval.startedAt
        endedAt = interval.endedAt
    }

    var interval: ActivityInterval? {
        guard let kind = ActivityKind(rawValue: kind) else { return nil }
        return ActivityInterval(kind: kind, startedAt: startedAt, endedAt: endedAt)
    }
}

@MainActor
protocol ActivityRecording {
    func insert(_ interval: ActivityInterval) async throws
    func insertBatch(_ values: [ActivityInterval]) async throws
    func intervals(from start: Date, to end: Date) throws -> [ActivityInterval]
    func intervalsAsync(from start: Date, to end: Date) async throws -> [ActivityInterval]
}

extension ActivityRecording {
    /// Compatibility for lightweight recording implementations. Production stores
    /// override this to perform the entire transaction on their worker.
    func insertBatch(_ values: [ActivityInterval]) async throws {
        for value in values { try await insert(value) }
    }

    func intervalsAsync(from start: Date, to end: Date) async throws -> [ActivityInterval] {
        try intervals(from: start, to: end)
    }
}

/// Stores and fetches activity intervals using SwiftData.
@MainActor
final class ActivityStore: ActivityRecording {
    private let context: ModelContext
    private let writer: HistoryWriteWorker
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
        writer = HistoryWriteWorker(container: container)
        context = ModelContext(container)
    }

    func insertBatch(_ values: [ActivityInterval]) async throws {
        try await writer.insert(values)
    }

    func insert(_ interval: ActivityInterval) async throws {
        try await insertBatch([interval])
    }

    func intervals(from start: Date, to end: Date) throws -> [ActivityInterval] {
        let descriptor = FetchDescriptor<ActivityRecord>(
            predicate: #Predicate { $0.startedAt < end && $0.endedAt > start },
            sortBy: [SortDescriptor(\.startedAt)]
        )
        return try PerformanceTrace.measure("Activity history fetch") {
            try context.fetch(descriptor).compactMap(\.interval)
        }
    }

    func intervalsAsync(from start: Date, to end: Date) async throws -> [ActivityInterval] {
        try await HistoryReadWorker.intervals(container: container, from: start, to: end)
    }
}
