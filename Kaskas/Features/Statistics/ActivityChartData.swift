import Foundation

/// Chart inputs prepared at data refresh, independent of hover/selection state.
nonisolated struct StudyTrendData: Sendable {
    struct Point: Identifiable, Equatable, Sendable {
        let date: Date
        let hours: Double
        let averageHours: Double
        var id: Date { date }
    }

    let points: [Point]
    var resolution: ActivityChartResolution = .day
    static let empty = Self(points: [])

    static func monthly(buckets: [ActivityChartBucket]) -> Self {
        Self(points: buckets.map {
            Point(date: $0.date, hours: $0.duration(for: .studying) / 3600, averageHours: 0)
        }, resolution: .month)
    }

    static func make(days: [DailyActivity], intervals: [ActivityInterval], calendar: Calendar = .current) -> Self {
        guard let start = days.first?.date, let end = days.last?.date else { return .empty }
        let averageStart = calendar.date(byAdding: .day, value: -6, to: start) ?? start
        let history = ActivityStatistics.days(from: averageStart, through: end, intervals: intervals, calendar: calendar)
        return make(days: days, history: history, calendar: calendar)
    }

    static func make(days: [DailyActivity], history: [DailyActivity], calendar: Calendar = .current) -> Self {
        let amounts = Dictionary(uniqueKeysWithValues: history.map { ($0.date, $0.studying) })
        return Self(points: days.map { day in
            let total = (0..<7).reduce(0.0) { result, distance in
                let date = calendar.date(byAdding: .day, value: -distance, to: day.date) ?? day.date
                return result + (amounts[date] ?? 0)
            }
            return Point(date: day.date, hours: day.studying / 3600, averageHours: total / 7 / 3600)
        })
    }
}

/// Temporal resolution is shared by marks, axes, and hover selection.
nonisolated enum ActivityChartResolution: Sendable {
    case day
    case month

    var component: Calendar.Component { self == .month ? .month : .day }

    func domain(for dates: [Date], calendar: Calendar = .current) -> ClosedRange<Date> {
        guard let first = dates.first, let last = dates.last else {
            return Date.distantPast...Date.distantPast.addingTimeInterval(86400)
        }
        if self == .month, let year = calendar.dateInterval(of: .year, for: first) {
            return year.start...year.end
        }
        let end = calendar.date(byAdding: .day, value: 1, to: last) ?? last.addingTimeInterval(86400)
        return first...end
    }

    func center(of date: Date, calendar: Calendar = .current) -> Date {
        guard let interval = calendar.dateInterval(of: component, for: date) else { return date }
        return interval.start.addingTimeInterval(interval.duration / 2)
    }
}

/// Totals for one calendar day or month. Daily source data remains available for summaries and averages.
nonisolated struct ActivityChartBucket: Identifiable, Sendable {
    let date: Date
    var durations: [ActivityKind: TimeInterval]
    var id: Date { date }

    func duration(for kind: ActivityKind) -> TimeInterval { durations[kind] ?? 0 }
    var total: TimeInterval { durations.values.reduce(0, +) }

    static func make(days: [DailyActivity], resolution: ActivityChartResolution,
                     calendar: Calendar = .current) -> [Self] {
        var buckets: [Date: Self] = [:]
        for day in days {
            let date = calendar.dateInterval(of: resolution.component, for: day.date)?.start ?? day.date
            var bucket = buckets[date] ?? Self(date: date, durations: [:])
            for kind in ActivityKind.allCases {
                bucket.durations[kind, default: 0] += day.duration(for: kind)
            }
            buckets[date] = bucket
        }
        return buckets.values.sorted { $0.date < $1.date }
    }
}

nonisolated struct YearHeatmapData: Sendable {
    let weeks: [[Date]]
    let activityByDate: [Date: TimeInterval]
    static let empty = Self(weeks: [], activityByDate: [:])

    static func make(year: Int, days: [DailyActivity], calendar: Calendar = .current) -> Self {
        guard let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let end = calendar.date(from: DateComponents(year: year, month: 12, day: 31)),
              let firstWeek = calendar.dateInterval(of: .weekOfYear, for: start)?.start else { return .empty }
        var weeks: [[Date]] = []
        var weekStart = firstWeek
        while weekStart <= end {
            weeks.append((0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) })
            guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart), next > weekStart else { break }
            weekStart = next
        }
        return Self(weeks: weeks, activityByDate: Dictionary(uniqueKeysWithValues: days.map { ($0.date, $0.studying) }))
    }
}
