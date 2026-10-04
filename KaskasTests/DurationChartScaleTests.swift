import Foundation
import Testing
@testable import Kaskas

struct DurationChartScaleTests {
    @Test func oneHourAxesShareFourMinuteLabelsRegardlessOfSourceUnits() {
        let hours = DurationChartScale(maximum: 0.25, minimum: 1, secondsPerUnit: 3600)
        let minutes = DurationChartScale(maximum: 15, minimum: 60, secondsPerUnit: 60)
        let locale = Locale(identifier: "tr_TR")
        func normalized(_ label: String) -> String {
            label.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        }
        let labels = ["0 dk", "20 dk", "40 dk", "60 dk"]
        #expect(hours.ticks.map { normalized(hours.label(for: $0, locale: locale)) } == labels)
        #expect(minutes.ticks.map { normalized(minutes.label(for: $0, locale: locale)) } == labels)
        #expect(hours.upperBound == 1)
        #expect(minutes.upperBound == 60)
        let english = hours.ticks.map { normalized(hours.label(for: $0, locale: Locale(identifier: "en_US"))) }
        #expect(english.last == "60 min")
    }

    @Test(arguments: [0.0, 1, 1.01, 2, 3, 6, 24, 25, 100, 744, 8760])
    func dynamicAxesKeepFourEvenMarksAndIncludeTheLargestValue(_ maximum: Double) {
        let scale = DurationChartScale(maximum: maximum, minimum: 1, secondsPerUnit: 3600)
        #expect(scale.ticks.count == 4)
        #expect(scale.ticks.first == 0)
        #expect(scale.ticks.last == scale.upperBound)
        #expect(scale.upperBound >= max(1, maximum))
        for index in 1..<4 {
            #expect(abs((scale.ticks[index] - scale.ticks[index - 1]) - scale.upperBound / 3) < 0.000001)
        }
    }

    @Test func repeatedDSTHourAndFullDayTotalsAreNotClipped() {
        let hourly = DurationChartScale(maximum: 120, minimum: 60, secondsPerUnit: 60)
        #expect(hourly.ticks == [0, 40, 80, 120])
        let daily = DurationChartScale(maximum: 24, minimum: 24, secondsPerUnit: 3600)
        #expect(daily.ticks == [0, 8, 16, 24])
        let extendedDay = DurationChartScale(maximum: 25, minimum: 24, secondsPerUnit: 3600)
        #expect(extendedDay.upperBound >= 25)
    }
}
