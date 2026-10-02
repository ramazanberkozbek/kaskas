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

    let today: DailyActivity
    let trend: StudyTrendData
    let distributionDays: [DailyActivity]
    let distributionPoints: [DistributionPoint]
    let hourlyDays: [DailyActivity]
    let hourlyPoints: [HourlyPoint]
    let hourlyUpperBound: Double
    let year: YearHeatmapData

    static let empty = Self(today: .init(date: .distantPast), trend: .empty, distributionDays: [],
                            distributionPoints: [], hourlyDays: [], hourlyPoints: [], hourlyUpperBound: 60, year: .empty)

    static func make(intervals: [ActivityInterval], now: Date, trendWindow: (start: Date, end: Date),
                     distributionWindow: (start: Date, end: Date), hourlyWindow: (start: Date, end: Date),
                     year: Int, calendar: Calendar = .current) -> Self {
        let today = ActivityStatistics.days(from: now, through: now, intervals: intervals, calendar: calendar).first
            ?? DailyActivity(date: calendar.startOfDay(for: now))
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
        return Self(today: today, trend: .make(days: trendDays, intervals: intervals, calendar: calendar),
                    distributionDays: distributionDays,
                    distributionPoints: distributionDays.flatMap { day in
                        ActivityKind.allCases.map { DistributionPoint(date: day.date, kind: $0, hours: day.duration(for: $0) / 3600) }
                    }, hourlyDays: hourlyDays, hourlyPoints: hourlyPoints,
                    hourlyUpperBound: max(60, (hourlyPoints.map(\.minutes).max() ?? 0).rounded(.up)),
                    year: .make(year: year, days: yearDays, calendar: calendar))
    }
}
