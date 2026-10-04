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
    static let empty = Self(points: [])

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
