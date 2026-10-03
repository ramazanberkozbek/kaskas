import Foundation
import SwiftData

@Model
final class BreakRecord {
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
    func insert(_ entry: BreakHistoryEntry) throws
}

@MainActor
final class BreakHistoryStore: BreakHistoryRecording {
    private let context: ModelContext

    init(container: ModelContainer) {
        context = ModelContext(container)
    }

    convenience init() throws {
        try self.init(container: ModelContainer(for: BreakRecord.self, ActivityRecord.self))
    }

    func insert(_ entry: BreakHistoryEntry) throws {
        let recordID = entry.id
        var descriptor = FetchDescriptor<BreakRecord>(
            predicate: #Predicate { $0.recordID == recordID }
        )
        descriptor.fetchLimit = 1
        guard try context.fetch(descriptor).isEmpty else { return }
        context.insert(BreakRecord(entry))
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    func entries(from start: Date, to end: Date) throws -> [BreakHistoryEntry] {
        let descriptor = FetchDescriptor<BreakRecord>(
            predicate: #Predicate { $0.occurredAt >= start && $0.occurredAt < end },
            sortBy: [SortDescriptor(\.occurredAt)]
        )
        return try context.fetch(descriptor).compactMap(\.entry)
    }
}
