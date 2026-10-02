import Foundation

struct DashboardChartSnapshot {
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
