import Foundation
import SwiftData

@Model
nonisolated final class AppUsageRecord {
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
    func insert(_ segment: AppUsageSegment) async throws
    func insertBatch(_ values: [AppUsageSegment]) async throws
    func segments(from start: Date, to end: Date) throws -> [AppUsageSegment]
    func segmentsAsync(from start: Date, to end: Date) async throws -> [AppUsageSegment]
}

extension AppUsageRecording {
    /// Compatibility for lightweight recording implementations. Production stores
    /// override this to perform the entire transaction on their worker.
    func insertBatch(_ values: [AppUsageSegment]) async throws {
        for value in values { try await insert(value) }
    }

    func segmentsAsync(from start: Date, to end: Date) async throws -> [AppUsageSegment] {
        try segments(from: start, to: end)
    }
}

/// Stores and fetches per-app usage segments using SwiftData.
@MainActor
final class AppUsageStore: AppUsageRecording {
    private let context: ModelContext
    private let writer: HistoryWriteWorker
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
        writer = HistoryWriteWorker(container: container)
        context = ModelContext(container)
    }

    func insertBatch(_ values: [AppUsageSegment]) async throws {
        try await writer.insert(values)
    }

    func insert(_ segment: AppUsageSegment) async throws {
        try await insertBatch([segment])
    }

    func segments(from start: Date, to end: Date) throws -> [AppUsageSegment] {
        let query = FetchDescriptor<AppUsageRecord>(predicate: #Predicate { $0.startedAt < end && $0.endedAt > start },
            sortBy: [SortDescriptor(\.startedAt)])
        return try context.fetch(query).map(\.segment)
    }

    func segmentsAsync(from start: Date, to end: Date) async throws -> [AppUsageSegment] {
        try await HistoryReadWorker.segments(container: container, from: start, to: end)
    }
}
