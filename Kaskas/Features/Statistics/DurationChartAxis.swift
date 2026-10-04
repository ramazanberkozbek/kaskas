import Charts
import SwiftUI

/// Four evenly spaced marks, with one duration unit shared by the entire axis.
nonisolated struct DurationChartScale {
    let upperBound: Double
    let ticks: [Double]
    private let secondsPerUnit: Double
    private let usesMinutes: Bool

    init(maximum: Double, minimum: Double, secondsPerUnit: Double) {
        self.secondsPerUnit = secondsPerUnit
        let requiredStep = max(minimum, maximum.isFinite ? maximum : minimum) * secondsPerUnit / 3
        let minuteSteps: [Double] = [20, 30, 40, 60]
        let step: Double
        if let minutes = minuteSteps.first(where: { $0 * 60 >= requiredStep }) {
            step = minutes * 60
        } else {
            let hours = requiredStep / 3600
            let magnitude = pow(10, floor(log10(hours)))
            let multiples: [Double] = [1, 2, 3, 4, 5, 6, 8, 10]
            let multiple = multiples.first { $0 * magnitude >= hours } ?? 10
            step = multiple * magnitude * 3600
        }
        upperBound = step * 3 / secondsPerUnit
        ticks = (0...3).map { Double($0) * step / secondsPerUnit }
        usesMinutes = step * 3 <= 3 * 3600
    }

    func label(for value: Double, locale: Locale) -> String {
        let seconds = max(0, value * secondsPerUnit)
        let unit: UnitDuration = usesMinutes || seconds == 0 ? .minutes : .hours
        let label = Measurement(value: seconds / (unit == .minutes ? 60 : 3600), unit: unit)
            .formatted(.measurement(width: .abbreviated, usage: .asProvided,
                numberFormatStyle: .number.precision(.fractionLength(0))).locale(locale))
        return label.replacingOccurrences(of: "dk.", with: "dk")
            .replacingOccurrences(of: "sa.", with: "sa")
    }
}

enum DurationChartAxis {
    @AxisContentBuilder
    static func marks(scale: DurationChartScale, locale: Locale) -> some AxisContent {
        AxisMarks(position: .trailing, values: scale.ticks) { value in
            AxisGridLine()
            AxisValueLabel {
                if let duration = value.as(Double.self) {
                    Text(scale.label(for: duration, locale: locale))
                }
            }
        }
    }
}
