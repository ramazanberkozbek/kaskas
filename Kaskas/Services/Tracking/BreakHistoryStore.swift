import Foundation
import SwiftData

@Model
nonisolated final class BreakRecord {
    @Attribute(.unique) var recordID: String
    var occurredAt: Date
    var startedAt: Date?
    var focusStartedAt: Date?
    var focusedDuration: TimeInterval?
    var outcome: String
    var source: String

    init(_ entry: BreakHistoryEntry) {
        recordID = entry.id
        occurredAt = entry.occurredAt
        startedAt = entry.startedAt
        focusStartedAt = entry.focusStartedAt
        focusedDuration = entry.focusedDuration
        outcome = entry.outcome.rawValue
        source = entry.source.rawValue
    }

    var entry: BreakHistoryEntry? {
        guard let outcome = BreakHistoryEntry.Outcome(rawValue: outcome),
              let source = BreakHistoryEntry.Source(rawValue: source) else { return nil }
        return BreakHistoryEntry(
            id: recordID,
            occurredAt: occurredAt,
            startedAt: startedAt,
            focusStartedAt: focusStartedAt,
            focusedDuration: focusedDuration,
            outcome: outcome,
            source: source
        )
    }
}

@MainActor
protocol BreakHistoryRecording {
    func insert(_ entry: BreakHistoryEntry) async throws
    func insertBatch(_ values: [BreakHistoryEntry]) async throws
}

extension BreakHistoryRecording {
    /// Compatibility for lightweight recording implementations. Production stores
    /// override this to perform the entire transaction on their worker.
    func insertBatch(_ values: [BreakHistoryEntry]) async throws {
        for value in values { try await insert(value) }
    }

}

/// Stores completed and skipped break history records using SwiftData.
@MainActor
final class BreakHistoryStore: BreakHistoryRecording {
    private let context: ModelContext
    private let writer: HistoryWriteWorker
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
        writer = HistoryWriteWorker(container: container)
        context = ModelContext(container)
    }

    convenience init() throws {
        try self.init(container: ModelContainer(for: BreakRecord.self, ActivityRecord.self))
    }

    func insertBatch(_ values: [BreakHistoryEntry]) async throws {
        try await writer.insert(values)
    }

    func insert(_ entry: BreakHistoryEntry) async throws {
        try await insertBatch([entry])
    }

    func entries(from start: Date, to end: Date) throws -> [BreakHistoryEntry] {
        let descriptor = FetchDescriptor<BreakRecord>(
            predicate: #Predicate { $0.occurredAt >= start && $0.occurredAt < end },
            sortBy: [SortDescriptor(\.occurredAt)]
        )
        return try context.fetch(descriptor).compactMap(\.entry)
    }

    func entriesAsync(from start: Date, to end: Date) async throws -> [BreakHistoryEntry] {
        try await HistoryReadWorker.entries(container: container, from: start, to: end)
    }
}
