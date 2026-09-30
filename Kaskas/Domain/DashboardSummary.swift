import Foundation

struct DashboardSummary {
    struct TimeRange: Identifiable {
        let id: Int
        let startHour: Double
        let endHour: Double
        let isToday: Bool
    }

    let today: TimeInterval
    let yesterday: TimeInterval
    let yesterdayAtThisTime: TimeInterval
    let week: [DailyActivity]
    let ranges: [TimeRange]
    let currentHour: Double

    var weekTotal: TimeInterval { week.reduce(0) { $0 + $1.studying } }

    static func make(
        intervals: [ActivityInterval],
        now: Date,
        calendar: Calendar = .current
    ) -> DashboardSummary {
        let todayDate = calendar.startOfDay(for: now)
        let yesterdayDate = calendar.date(byAdding: .day, value: -1, to: todayDate) ?? todayDate
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? todayDate
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? todayDate
        let days = ActivityStatistics.days(from: weekStart, through: weekEnd, intervals: intervals, calendar: calendar)
        let previousDay = ActivityStatistics.days(from: yesterdayDate, through: yesterdayDate, intervals: intervals, calendar: calendar)
        let yesterdayRanges = ActivityStatistics.focusRanges(on: yesterdayDate, intervals: intervals, calendar: calendar)
        let todayRanges = ActivityStatistics.focusRanges(on: todayDate, intervals: intervals, calendar: calendar)
        let clock = calendar.dateComponents([.hour, .minute, .second], from: now)
        let cutoff = calendar.date(
            bySettingHour: clock.hour ?? 0,
            minute: clock.minute ?? 0,
            second: clock.second ?? 0,
            of: yesterdayDate
        ) ?? yesterdayDate

        func hour(_ date: Date, on day: Date) -> Double {
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: day), date >= dayEnd else {
                let parts = calendar.dateComponents([.hour, .minute, .second], from: date)
                return Double(parts.hour ?? 0) + Double(parts.minute ?? 0) / 60 + Double(parts.second ?? 0) / 3600
            }
            return 24
        }

        var ranges: [TimeRange] = []
        for (isToday, day, source) in [(false, yesterdayDate, yesterdayRanges), (true, todayDate, todayRanges)] {
            for range in source where range.end > range.start {
                ranges.append(TimeRange(id: ranges.count, startHour: hour(range.start, on: day), endHour: hour(range.end, on: day), isToday: isToday))
            }
        }

        return DashboardSummary(
            today: ActivityStatistics.days(from: todayDate, through: todayDate, intervals: intervals, calendar: calendar).first?.studying ?? 0,
            yesterday: previousDay.first?.studying ?? 0,
            yesterdayAtThisTime: yesterdayRanges.reduce(0) { $0 + max(0, min($1.end, cutoff).timeIntervalSince($1.start)) },
            week: days,
            ranges: ranges,
            currentHour: hour(now, on: todayDate)
        )
    }
}
