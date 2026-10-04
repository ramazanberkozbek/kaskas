import SwiftUI

enum StatisticsStyle {
    static let studying = Color(red: 0.27, green: 0.79, blue: 0.57)
    static let breakTime = Color(red: 0.94, green: 0.69, blue: 0.32)
    static let computerInactive = Color(red: 0.40, green: 0.72, blue: 0.84)
    static let kaskasPaused = Color(red: 0.66, green: 0.54, blue: 0.91)
    static let meeting = Color(red: 0.85, green: 0.48, blue: 0.73)
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
        case .meeting: StatisticsStyle.meeting
        }
    }

    var labelKey: String {
        switch self {
        case .studying: "stats.kind.studying"
        case .breakTime: "stats.kind.breakTime"
        case .computerInactive: "stats.kind.computerInactive"
        case .kaskasPaused: "stats.kind.kaskasPaused"
        case .meeting: "stats.kind.meeting"
        }
    }
}

enum StatisticsPeriod: Int, CaseIterable, Identifiable {
    case day = 1
    case seven = 7
    case thirty = 30
    case year = 365

    var id: Self { self }

    var labelKey: String {
        switch self {
        case .day: "stats.hourly.day"
        case .seven: "stats.period.seven"
        case .thirty: "stats.period.thirty"
        case .year: "stats.period.year"
        }
    }

    var usesHourlyAverage: Bool { self == .thirty || self == .year }

    func window(endingAt endDate: Date, calendar: Calendar = .current) -> (start: Date, end: Date) {
        let end = calendar.startOfDay(for: endDate)
        switch self {
        case .day:
            return (end, end)
        case .seven:
            return (calendar.date(byAdding: .day, value: -6, to: end) ?? end, end)
        case .thirty, .year:
            let component: Calendar.Component = self == .thirty ? .month : .year
            guard let interval = calendar.dateInterval(of: component, for: end) else { return (end, end) }
            let lastDay = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? end
            return (interval.start, lastDay)
        }
    }

    func shiftedDate(_ date: Date, by direction: Int, calendar: Calendar = .current) -> Date {
        let component: Calendar.Component = switch self {
        case .day, .seven: .day
        case .thirty: .month
        case .year: .year
        }
        let amount = self == .seven ? 7 : 1
        return calendar.date(byAdding: component, value: direction * amount, to: date) ?? date
    }

    func rangeLabel(endingAt date: Date, locale: Locale, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        switch self {
        case .day:
            if locale.language.languageCode?.identifier == "tr" {
                formatter.dateFormat = "EEEE d MMMM"
            } else {
                formatter.setLocalizedDateFormatFromTemplate("EEEE d MMMM")
            }
        case .seven:
            let window = window(endingAt: date, calendar: calendar)
            let crossesYear = calendar.component(.year, from: window.start) != calendar.component(.year, from: window.end)
            formatter.setLocalizedDateFormatFromTemplate(crossesYear ? "d MMMM yyyy" : "d MMMM")
            let start = formatter.string(from: window.start)
            formatter.setLocalizedDateFormatFromTemplate("d MMMM yyyy")
            return "\(start)–\(formatter.string(from: window.end))"
        case .thirty:
            formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        case .year:
            formatter.setLocalizedDateFormatFromTemplate("yyyy")
        }
        return formatter.string(from: date)
    }
}

enum HourlyPeriod {
    case day
    case week
}

enum StatisticsDuration {
    static func label(_ seconds: TimeInterval, locale: Locale = AppLanguage.currentLocale) -> String {
        let value = max(0, seconds)
        let isTurkish = locale.language.languageCode?.identifier == "tr" || locale.identifier.hasPrefix("tr")
        if value < 3600 {
            let label = Measurement(value: value / 60, unit: UnitDuration.minutes)
                .formatted(.measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0))).locale(locale))
            return isTurkish ? label.replacingOccurrences(of: "dk.", with: "dk") : label
        }
        let label = Measurement(value: value / 3600, unit: UnitDuration.hours)
            .formatted(.measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(1))).locale(locale))
        return isTurkish ? label.replacingOccurrences(of: "sa.", with: "sa") : label
    }
}
