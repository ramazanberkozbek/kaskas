import Foundation

nonisolated struct DailyStudyChartData: Sendable {
    let date: Date
    let todayHours: [Double]
    let yesterdayHours: [Double]

    static let empty = Self(date: .distantPast, todayHours: Array(repeating: 0, count: 24),
                            yesterdayHours: Array(repeating: 0, count: 24))

    func currentLabelKey(at now: Date, calendar: Calendar = .current) -> String {
        calendar.isDate(date, inSameDayAs: now) ? "dashboard.today" : "dashboard.day.selected"
    }

    func previousLabelKey(at now: Date, calendar: Calendar = .current) -> String {
        calendar.isDate(date, inSameDayAs: now) ? "dashboard.yesterday" : "dashboard.day.previous"
    }

    func visibleHours(at now: Date, calendar: Calendar = .current) -> Range<Int> {
        if calendar.isDate(date, inSameDayAs: now) {
            return 0..<(calendar.component(.hour, from: now) + 1)
        }
        return calendar.startOfDay(for: date) < calendar.startOfDay(for: now) ? 0..<24 : 0..<0
    }

    func position(for hour: Int, at now: Date, calendar: Calendar = .current) -> Double {
        let center = Double(hour) + 0.5
        guard calendar.isDate(date, inSameDayAs: now) else { return center }
        let components = calendar.dateComponents([.hour, .minute, .second], from: now)
        let currentPosition = Double(components.hour ?? 0)
            + Double(components.minute ?? 0) / 60
            + Double(components.second ?? 0) / 3600
        return min(center, currentPosition)
    }

    static func make(date: Date, intervals: [ActivityInterval], calendar: Calendar = .current) -> Self {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: date) ?? date
        return Self(date: date,
                    todayHours: ActivityStatistics.focusMinutesByHour(on: date, intervals: intervals, calendar: calendar).map { $0 / 60 },
                    yesterdayHours: ActivityStatistics.focusMinutesByHour(on: yesterday, intervals: intervals, calendar: calendar).map { $0 / 60 })
    }
}
