import Foundation
import SwiftData

/// Every read owns its context on the concurrent executor. SwiftData models never
/// cross the executor boundary; only immutable history values are returned.
nonisolated enum HistoryReadWorker {
    @concurrent static func intervals(container: ModelContainer, from start: Date, to end: Date) async throws -> [ActivityInterval] {
        try Task.checkCancellation()
        let context = ModelContext(container)
        let query = FetchDescriptor<ActivityRecord>(
            predicate: #Predicate { $0.startedAt < end && $0.endedAt > start },
            sortBy: [SortDescriptor(\.startedAt)])
        return try PerformanceTrace.measure("Activity history fetch") {
            try context.fetch(query).compactMap(\.interval)
        }
    }

    @concurrent static func segments(container: ModelContainer, from start: Date, to end: Date) async throws -> [AppUsageSegment] {
        try Task.checkCancellation()
        let context = ModelContext(container)
        let query = FetchDescriptor<AppUsageRecord>(
            predicate: #Predicate { $0.startedAt < end && $0.endedAt > start },
            sortBy: [SortDescriptor(\.startedAt)])
        return try context.fetch(query).map(\.segment)
    }

    @concurrent static func entries(container: ModelContainer, from start: Date, to end: Date) async throws -> [BreakHistoryEntry] {
        try Task.checkCancellation()
        let context = ModelContext(container)
        let query = FetchDescriptor<BreakRecord>(
            predicate: #Predicate { $0.occurredAt >= start && $0.occurredAt < end },
            sortBy: [SortDescriptor(\.occurredAt)])
        return try context.fetch(query).compactMap(\.entry)
    }
}
