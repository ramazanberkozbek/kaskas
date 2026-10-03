import Foundation

/// Validates custom durations before they enter persisted configuration.
enum DurationInput {
    static let maximumDuration: TimeInterval = 240 * 60

    enum Unit: Hashable {
        case seconds, minutes, hours

        var multiplier: TimeInterval {
            switch self {
            case .seconds: 1
            case .minutes: 60
            case .hours: 3_600
            }
        }
    }

    static func seconds(from input: String, unit: Unit, locale: Locale,
                        minimum: TimeInterval = 1,
                        maximum: TimeInterval = maximumDuration,
                        step: TimeInterval = 1) -> TimeInterval? {
        let scanner = Scanner(string: input.trimmingCharacters(in: .whitespacesAndNewlines))
        scanner.locale = locale
        guard let amount = scanner.scanDouble(), scanner.isAtEnd else { return nil }
        let seconds = amount * unit.multiplier
        guard seconds.isFinite, seconds >= minimum, seconds <= min(maximum, maximumDuration),
              seconds < Double(Int.max), step > 0 else { return nil }
        let rounded = (seconds / step).rounded() * step
        guard abs(seconds - rounded) < 0.000_001 else { return nil }
        return rounded
    }

    /// Forces custom durations into the valid minimum, maximum, and step bounds.
    static func clampedSeconds(from amount: Double,
                               unit: Unit,
                               minimum: TimeInterval = 1,
                               maximum: TimeInterval = maximumDuration,
                               step: TimeInterval = 1) -> TimeInterval {
        let minUnits = max(1, Int((minimum / unit.multiplier).rounded()))
        let maxUnits = max(1, Int((min(maximum, maximumDuration) / unit.multiplier).rounded()))
        let stepUnits = max(1, Int((step / unit.multiplier).rounded()))

        let intAmount = Int(amount.rounded())
        let clampedUnits = min(maxUnits, max(minUnits, intAmount))

        let steppedUnits: Int
        if stepUnits > 1 {
            let rounded = (Double(clampedUnits) / Double(stepUnits)).rounded() * Double(stepUnits)
            steppedUnits = min(maxUnits, max(minUnits, Int(rounded)))
        } else {
            steppedUnits = clampedUnits
        }

        return Double(steppedUnits) * unit.multiplier
    }
}
