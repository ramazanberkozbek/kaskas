import Foundation

nonisolated struct DashboardTodayChartData: Sendable {
    let date: Date
    let todayHours: [Double]
    let yesterdayHours: [Double]

    static let empty = Self(date: .distantPast, todayHours: Array(repeating: 0, count: 24),
                            yesterdayHours: Array(repeating: 0, count: 24))

    static func make(date: Date, intervals: [ActivityInterval], calendar: Calendar = .current) -> Self {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: date) ?? date
        return Self(date: date,
                    todayHours: ActivityStatistics.focusMinutesByHour(on: date, intervals: intervals, calendar: calendar).map { $0 / 60 },
                    yesterdayHours: ActivityStatistics.focusMinutesByHour(on: yesterday, intervals: intervals, calendar: calendar).map { $0 / 60 })
    }
}
