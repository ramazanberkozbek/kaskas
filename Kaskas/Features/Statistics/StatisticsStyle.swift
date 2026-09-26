import SwiftUI

enum StatisticsStyle {
    static let studying = Color(red: 0.27, green: 0.79, blue: 0.57)
    static let breakTime = Color(red: 0.94, green: 0.69, blue: 0.32)
    static let computerInactive = Color(red: 0.40, green: 0.72, blue: 0.84)
    static let kaskasPaused = Color(red: 0.66, green: 0.54, blue: 0.91)
    static let average = Color(red: 0.58, green: 0.51, blue: 0.94)

    static func panelFill(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.14, green: 0.14, blue: 0.16)
            : Color(nsColor: .controlBackgroundColor)
    }
}

extension ActivityKind {
    var color: Color {
        switch self {
        case .studying: StatisticsStyle.studying
        case .breakTime: StatisticsStyle.breakTime
        case .computerInactive: StatisticsStyle.computerInactive
        case .kaskasPaused: StatisticsStyle.kaskasPaused
        }
    }

    var labelKey: String {
        switch self {
        case .studying: "stats.kind.studying"
        case .breakTime: "stats.kind.breakTime"
        case .computerInactive: "stats.kind.computerInactive"
        case .kaskasPaused: "stats.kind.kaskasPaused"
        }
    }

    var symbol: String {
        switch self {
        case .studying: "book.closed.fill"
        case .breakTime: "cup.and.saucer.fill"
        case .computerInactive: "moon.zzz.fill"
        case .kaskasPaused: "pause.circle.fill"
        }
    }
}

enum StatisticsPeriod: Int, CaseIterable, Identifiable {
    case seven = 7
    case thirty = 30

    var id: Self { self }

    var labelKey: String { self == .seven ? "stats.period.seven" : "stats.period.thirty" }

    func window(offset: Int, now: Date, calendar: Calendar = .current) -> (start: Date, end: Date) {
        let today = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: -offset * rawValue, to: today) ?? today
        let start = calendar.date(byAdding: .day, value: 1 - rawValue, to: end) ?? end
        return (start, end)
    }
}

enum StatisticsDuration {
    static func label(_ seconds: TimeInterval) -> String {
        let value = max(0, seconds)
        if value < 3600 {
            return Measurement(value: value / 60, unit: UnitDuration.minutes)
                .formatted(.measurement(width: .abbreviated, numberFormatStyle: .number.precision(.fractionLength(0))))
        }
        return Measurement(value: value / 3600, unit: UnitDuration.hours)
            .formatted(.measurement(width: .abbreviated, numberFormatStyle: .number.precision(.fractionLength(1))))
    }
}
