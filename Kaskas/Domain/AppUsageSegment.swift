import Foundation

nonisolated struct ForegroundApp: Codable, Equatable, Sendable {
    let bundleID: String?
    let name: String
}

nonisolated struct AppUsageSegment: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let app: ForegroundApp
    let resolution: CategoryResolution
    let startedAt: Date
    let endedAt: Date
}

nonisolated struct AppUsageCursor: Codable, Equatable, Sendable {
    let id: UUID
    let app: ForegroundApp
    let resolution: CategoryResolution
    let startedAt: Date
    var checkpointAt: Date

    func segment(endingAt end: Date) -> AppUsageSegment {
        AppUsageSegment(id: id, app: app, resolution: resolution, startedAt: startedAt, endedAt: max(startedAt, end))
    }
}

nonisolated struct AppUsageJournal: Codable, Equatable, Sendable {
    var cursor: AppUsageCursor?
    var pending: [AppUsageSegment] = []
}
