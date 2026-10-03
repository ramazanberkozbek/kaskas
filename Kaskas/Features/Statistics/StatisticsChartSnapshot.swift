import Foundation

struct StatisticsChartSnapshot {
    struct DistributionPoint: Identifiable {
        let date: Date
        let kind: ActivityKind
        let hours: Double
        var id: String { "\(date.timeIntervalSinceReferenceDate)-\(kind.rawValue)" }
    }

    struct HourlyPoint: Identifiable {
        let date: Date
        let hour: Int
        let minutes: Double
        var id: String { "\(date.timeIntervalSinceReferenceDate)-\(hour)" }
    }

    let trend: StudyTrendData
    let distributionDays: [DailyActivity]
    let distributionPoints: [DistributionPoint]
    let hourlyDays: [DailyActivity]
    let hourlyPoints: [HourlyPoint]
    let year: YearHeatmapData

    /// Includes empty days so the monthly view shows a daily average, not a total.
    var averageHourlyPoints: [HourlyPoint] {
        guard let lastDay = hourlyDays.last else { return [] }
        var totals = Array(repeating: 0.0, count: 24)
        for point in hourlyPoints { totals[point.hour] += point.minutes }
        return totals.enumerated().map { hour, minutes in
            HourlyPoint(date: lastDay.date, hour: hour, minutes: minutes / Double(hourlyDays.count))
        }
    }

    static let empty = Self(trend: .empty, distributionDays: [], distributionPoints: [],
                            hourlyDays: [], hourlyPoints: [], year: .empty)

    static func make(intervals: [ActivityInterval], trendWindow: (start: Date, end: Date),
                     distributionWindow: (start: Date, end: Date), hourlyWindow: (start: Date, end: Date),
                     year: Int, calendar: Calendar = .current) -> Self {
        let trendDays = ActivityStatistics.days(from: trendWindow.start, through: trendWindow.end, intervals: intervals, calendar: calendar)
        let distributionDays = ActivityStatistics.days(from: distributionWindow.start, through: distributionWindow.end, intervals: intervals, calendar: calendar)
        let hourlyDays = ActivityStatistics.days(from: hourlyWindow.start, through: hourlyWindow.end, intervals: intervals, calendar: calendar)
        let hourlyPoints = hourlyDays.flatMap { day in
            ActivityStatistics.focusMinutesByHour(on: day.date, intervals: intervals, calendar: calendar).enumerated().map { hour, minutes in
                HourlyPoint(date: day.date, hour: hour, minutes: minutes)
            }
        }
        let yearDays: [DailyActivity]
        if let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
           let end = calendar.date(from: DateComponents(year: year, month: 12, day: 31)) {
            yearDays = ActivityStatistics.days(from: start, through: end, intervals: intervals, calendar: calendar)
        } else { yearDays = [] }
        return Self(trend: .make(days: trendDays, intervals: intervals, calendar: calendar),
                    distributionDays: distributionDays,
                    distributionPoints: distributionDays.flatMap { day in
                        ActivityKind.allCases.map { DistributionPoint(date: day.date, kind: $0, hours: day.duration(for: $0) / 3600) }
                    }, hourlyDays: hourlyDays, hourlyPoints: hourlyPoints,
                    year: .make(year: year, days: yearDays, calendar: calendar))
    }
}
