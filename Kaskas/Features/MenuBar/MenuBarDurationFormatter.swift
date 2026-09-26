import Foundation

enum MenuBarDurationFormatter {
    static func string(for remaining: TimeInterval, locale: Locale = .current) -> String {
        let minutes = max(1, Int(ceil(remaining / 60)))
        let hours = minutes / 60
        let extraMinutes = minutes % 60
        let format = Measurement<UnitDuration>.FormatStyle(
            width: .abbreviated,
            usage: .asProvided
        ).locale(locale)
        func minuteLabel(_ value: Int) -> String {
            let label = Measurement(value: Double(value), unit: UnitDuration.minutes).formatted(format)
            return locale.languageCode == "tr"
                ? label.replacingOccurrences(of: "dk.", with: "dk")
                : label
        }

        if hours == 0 {
            return minuteLabel(minutes)
        }
        let hourLabel = Measurement(value: Double(hours), unit: UnitDuration.hours).formatted(format)
        guard extraMinutes > 0 else { return hourLabel }
        return "\(hourLabel) \(minuteLabel(extraMinutes))"
    }
}
