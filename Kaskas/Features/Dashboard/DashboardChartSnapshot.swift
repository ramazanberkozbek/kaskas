import Foundation

nonisolated struct DashboardChartSnapshot: Sendable {
    let days: [DailyActivity]
    let today: DashboardTodayChartData
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
                                date: Date, weekStart: Date, sessionEnd: Date, calendar: Calendar) async throws -> Self {
        try Task.checkCancellation()
        let selectedDay = calendar.startOfDay(for: date)
        let timeline = CategoryUsageSummary.Timeline(usage: usage)
        func categories(from start: Date) -> DashboardCategorySnapshot {
            let target = intervals.filter { $0.kind == .studying && $0.startedAt >= start && $0.startedAt < sessionEnd }
            let sessions = Array(StudySessionGrouping.group(target, breakEntries: breaks).reversed())
            return .make(intervals: intervals, timeline: timeline, sessions: sessions, from: start, to: sessionEnd)
        }
        return Self(day: categories(from: selectedDay), week: categories(from: weekStart),
                    chart: .make(intervals: intervals, date: date, weekStart: weekStart, calendar: calendar))
    }
}
