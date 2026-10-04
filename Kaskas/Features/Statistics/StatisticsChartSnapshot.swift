import Foundation

nonisolated struct StatisticsChartSnapshot: Sendable {
    struct DistributionPoint: Identifiable, Sendable {
        let date: Date
        let kind: ActivityKind
        let hours: Double
        var id: String { "\(date.timeIntervalSinceReferenceDate)-\(kind.rawValue)" }
    }

    struct HourlyPoint: Identifiable, Sendable {
        let date: Date
        let hour: Int
        let minutes: Double
        var id: String { "\(date.timeIntervalSinceReferenceDate)-\(hour)" }
    }

    let dailyTrend: DailyStudyChartData
    let trend: StudyTrendData
    let distributionDays: [DailyActivity]
    let distributionBuckets: [ActivityChartBucket]
    let distributionPoints: [DistributionPoint]
    let hourlyDays: [DailyActivity]
    let hourlyPoints: [HourlyPoint]
    let year: YearHeatmapData

    /// Includes empty days so monthly and yearly views show a daily average.
    var averageHourlyPoints: [HourlyPoint] {
        guard let lastDay = hourlyDays.last else { return [] }
        var totals = Array(repeating: 0.0, count: 24)
        for point in hourlyPoints { totals[point.hour] += point.minutes }
        return totals.enumerated().map { hour, minutes in
            HourlyPoint(date: lastDay.date, hour: hour, minutes: minutes / Double(hourlyDays.count))
        }
    }

    static let empty = Self(dailyTrend: .empty, trend: .empty, distributionDays: [], distributionBuckets: [], distributionPoints: [],
                            hourlyDays: [], hourlyPoints: [], year: .empty)

    static func make(intervals: [ActivityInterval], trendWindow: (start: Date, end: Date),
                     distributionWindow: (start: Date, end: Date), hourlyWindow: (start: Date, end: Date),
                     year: Int, calendar: Calendar = .current, period: StatisticsPeriod = .seven) -> Self {
        let yearStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1))
        let yearEnd = calendar.date(from: DateComponents(year: year, month: 12, day: 31))
        let averageStart = calendar.date(byAdding: .day, value: -6, to: trendWindow.start) ?? trendWindow.start
        let first = min(averageStart, distributionWindow.start, hourlyWindow.start, yearStart ?? averageStart)
        let last = max(trendWindow.end, distributionWindow.end, hourlyWindow.end, yearEnd ?? trendWindow.end)
        // One daily aggregation supplies every chart and the rolling-average history.
        let history = ActivityStatistics.days(from: first, through: last, intervals: intervals, calendar: calendar)
        func days(in window: (start: Date, end: Date)) -> [DailyActivity] {
            let start = calendar.startOfDay(for: window.start)
            let end = calendar.startOfDay(for: window.end)
            return history.filter { $0.date >= start && $0.date <= end }
        }
        let trendDays = days(in: trendWindow)
        let distributionDays = days(in: distributionWindow)
        let resolution: ActivityChartResolution = period == .year ? .month : .day
        let distributionBuckets = ActivityChartBucket.make(days: distributionDays, resolution: resolution, calendar: calendar)
        let hourlyDays = days(in: hourlyWindow)
        let minutesByDay = ActivityStatistics.focusMinutesByDay(from: hourlyWindow.start, through: hourlyWindow.end,
            intervals: intervals, calendar: calendar)
        let hourlyPoints = hourlyDays.flatMap { day in
            (minutesByDay[day.date] ?? Array(repeating: 0, count: 24)).enumerated().map { hour, minutes in
                HourlyPoint(date: day.date, hour: hour, minutes: minutes)
            }
        }
        let yearDays = if let yearStart, let yearEnd { days(in: (yearStart, yearEnd)) } else { [DailyActivity]() }
        return Self(dailyTrend: .make(date: trendWindow.end, intervals: intervals, calendar: calendar),
                    trend: period == .year
                        ? .monthly(buckets: ActivityChartBucket.make(days: trendDays, resolution: .month, calendar: calendar))
                        : .make(days: trendDays, history: history, calendar: calendar),
                    distributionDays: distributionDays,
                    distributionBuckets: distributionBuckets,
                    distributionPoints: distributionBuckets.flatMap { day in
                        ActivityKind.allCases.map { DistributionPoint(date: day.date, kind: $0, hours: day.duration(for: $0) / 3600) }
                    }, hourlyDays: hourlyDays, hourlyPoints: hourlyPoints,
                    year: .make(year: year, days: yearDays, calendar: calendar))
    }
}

nonisolated struct StatisticsRefreshSnapshot: Sendable {
    let categories: CategoryUsageSummary
    let chart: StatisticsChartSnapshot

    @concurrent static func make(intervals: [ActivityInterval], usage: [AppUsageSegment],
                                window: (start: Date, end: Date), categoryEnd: Date,
                                year: Int, calendar: Calendar, period: StatisticsPeriod) async throws -> Self {
        try Task.checkCancellation()
        return Self(categories: .make(intervals: intervals, usage: usage, from: window.start, to: categoryEnd),
             chart: .make(intervals: intervals, trendWindow: window, distributionWindow: window,
                          hourlyWindow: window, year: year, calendar: calendar, period: period))
    }
}
