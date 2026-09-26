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

        if hours == 0 {
            return Measurement(value: Double(minutes), unit: UnitDuration.minutes).formatted(format)
        }
        let hourLabel = Measurement(value: Double(hours), unit: UnitDuration.hours).formatted(format)
        guard extraMinutes > 0 else { return hourLabel }
        let minuteLabel = Measurement(value: Double(extraMinutes), unit: UnitDuration.minutes).formatted(format)
        return "\(hourLabel) \(minuteLabel)"
    }
}
