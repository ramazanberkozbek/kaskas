import Foundation

enum MenuBarDurationFormatter {
    static func string(for remaining: TimeInterval, locale: Locale = .current) -> String {
        let minutes = max(1, Int(ceil(remaining / 60)))
        let hours = minutes / 60
        let extraMinutes = minutes % 60
        let isTurkish = locale.language.languageCode?.identifier == "tr" || locale.identifier.hasPrefix("tr")
        let format = Measurement<UnitDuration>.FormatStyle(
            width: .abbreviated,
            usage: .asProvided
        ).locale(locale)
        func minuteLabel(_ value: Int) -> String {
            let label = Measurement(value: Double(value), unit: UnitDuration.minutes).formatted(format)
            return isTurkish
                ? label.replacingOccurrences(of: "dk.", with: "dk")
                : label
        }

        if hours == 0 {
            return minuteLabel(minutes)
        }
        let hourLabel = Measurement(value: Double(hours), unit: UnitDuration.hours).formatted(format)
        let cleanHourLabel = isTurkish ? hourLabel.replacingOccurrences(of: "sa.", with: "sa") : hourLabel
        guard extraMinutes > 0 else { return cleanHourLabel }
        return "\(cleanHourLabel) \(minuteLabel(extraMinutes))"
    }

    static func screenTimeString(for seconds: TimeInterval, locale: Locale = .current) -> String {
        let totalMinutes = max(0, Int(seconds / 60))
        let hours = totalMinutes / 60
        let extraMinutes = totalMinutes % 60
        let isTurkish = locale.language.languageCode?.identifier == "tr" || locale.identifier.hasPrefix("tr")
        let format = Measurement<UnitDuration>.FormatStyle(
            width: .abbreviated,
            usage: .asProvided
        ).locale(locale)

        func minuteLabel(_ value: Int) -> String {
            let label = Measurement(value: Double(value), unit: UnitDuration.minutes).formatted(format)
            return isTurkish ? label.replacingOccurrences(of: "dk.", with: "dk") : label
        }

        func hourLabel(_ value: Int) -> String {
            let label = Measurement(value: Double(value), unit: UnitDuration.hours).formatted(format)
            return isTurkish ? label.replacingOccurrences(of: "sa.", with: "sa") : label
        }

        if hours == 0 {
            return minuteLabel(extraMinutes)
        }
        guard extraMinutes > 0 else { return hourLabel(hours) }
        return "\(hourLabel(hours)) \(minuteLabel(extraMinutes))"
    }
}
