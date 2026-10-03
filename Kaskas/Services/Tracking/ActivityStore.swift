import Foundation
import SwiftData

@Model
final class ActivityRecord {
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
    func insert(_ interval: ActivityInterval) throws
    func intervals(from start: Date, to end: Date) throws -> [ActivityInterval]
}

/// Stores and fetches activity intervals using SwiftData.
@MainActor
final class ActivityStore: ActivityRecording {
    private let context: ModelContext

    init(container: ModelContainer) {
        context = ModelContext(container)
    }

    func insert(_ interval: ActivityInterval) throws {
        let recordID = interval.id
        var descriptor = FetchDescriptor<ActivityRecord>(
            predicate: #Predicate { $0.recordID == recordID }
        )
        descriptor.fetchLimit = 1
        guard try context.fetch(descriptor).isEmpty else { return }
        context.insert(ActivityRecord(interval))
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
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
}
