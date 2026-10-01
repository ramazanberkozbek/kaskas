import Foundation
import SwiftData

@Model
final class AppUsageRecord {
    @Attribute(.unique) var recordID: UUID
    var bundleID: String?
    var appName: String
    var categoryID: String
    var source: String
    var ruleKey: String?
    var startedAt: Date
    var endedAt: Date

    init(_ segment: AppUsageSegment) {
        recordID = segment.id
        bundleID = segment.app.bundleID
        appName = segment.app.name
        categoryID = segment.resolution.categoryID
        source = segment.resolution.source.rawValue
        ruleKey = segment.resolution.ruleKey
        startedAt = segment.startedAt
        endedAt = segment.endedAt
    }

    var segment: AppUsageSegment {
        AppUsageSegment(id: recordID, app: ForegroundApp(bundleID: bundleID, name: appName),
            resolution: CategoryResolution(categoryID: categoryID, source: CategoryResolution.Source(rawValue: source) ?? .unmatched, ruleKey: ruleKey),
            startedAt: startedAt, endedAt: endedAt)
    }
}

@MainActor
protocol AppUsageRecording {
    func insert(_ segment: AppUsageSegment) throws
    func segments(from start: Date, to end: Date) throws -> [AppUsageSegment]
}

@MainActor
final class AppUsageStore: AppUsageRecording {
    private let context: ModelContext

    init(container: ModelContainer) { context = ModelContext(container) }

    func insert(_ segment: AppUsageSegment) throws {
        let id = segment.id
        var query = FetchDescriptor<AppUsageRecord>(predicate: #Predicate { $0.recordID == id })
        query.fetchLimit = 1
        guard try context.fetch(query).isEmpty else { return }
        context.insert(AppUsageRecord(segment))
        do { try context.save() } catch { context.rollback(); throw error }
    }

    func segments(from start: Date, to end: Date) throws -> [AppUsageSegment] {
        let query = FetchDescriptor<AppUsageRecord>(predicate: #Predicate { $0.startedAt < end && $0.endedAt > start },
            sortBy: [SortDescriptor(\.startedAt)])
        return try context.fetch(query).map(\.segment)
    }
}
