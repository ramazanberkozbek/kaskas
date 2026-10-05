import Foundation

nonisolated struct DashboardChartSnapshot: Sendable {
    let days: [DailyActivity]
    let today: DailyStudyChartData
    let trend: StudyTrendData

    static let empty = Self(days: [], today: .empty, trend: .empty)

    static func make(intervals: [ActivityInterval], date: Date, weekStart: Date, calendar: Calendar = .current) -> Self {
        let days = ActivityStatistics.days(from: weekStart, through: date, intervals: intervals, calendar: calendar)
        return Self(days: days, today: .make(date: date, intervals: intervals, calendar: calendar),
                    trend: .make(days: days, intervals: intervals, calendar: calendar))
    }
}

/// Prepares both picker periods together, away from the main actor.
nonisolated struct DashboardRefreshSnapshot: Sendable {
    let day: DashboardCategorySnapshot
    let week: DashboardCategorySnapshot
    let chart: DashboardChartSnapshot

    @concurrent static func make(intervals: [ActivityInterval], usage: [AppUsageSegment], breaks: [BreakHistoryEntry],
                                date: Date, weekStart: Date, sessionEnd: Date, calendar: Calendar,
                                excluded: [ExcludedUsageInterval] = [], exclusions: AppExclusionSnapshot = .empty) async throws -> Self {
        try Task.checkCancellation()
        let selectedDay = calendar.startOfDay(for: date)
        let projection = StudyTimeProjection(intervals: intervals, usage: usage, excluded: excluded, exclusions: exclusions)
        let timeline = projection.timeline
        func categories(from start: Date) -> DashboardCategorySnapshot {
            let target = intervals.filter { $0.kind == .studying && $0.startedAt >= start && $0.startedAt < sessionEnd }
            let sessions = Array(StudySessionGrouping.group(target, breakEntries: breaks).compactMap { projection.session($0) }.reversed())
            return .make(intervals: projection.intervals, timeline: timeline, sessions: sessions, from: start, to: sessionEnd)
        }
        return Self(day: categories(from: selectedDay), week: categories(from: weekStart),
                    chart: .make(intervals: projection.intervals, date: date, weekStart: weekStart, calendar: calendar))
    }
}
