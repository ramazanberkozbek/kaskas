import Foundation
import Testing
@testable import Kaskas

struct ActivityStatisticsTests {
    @Test
    func splitsIntervalsAtLocalMidnightWithoutMixingCategories() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Istanbul"))
        let firstDay = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 25)))
        let midnight = try #require(calendar.date(byAdding: .day, value: 1, to: firstDay))
        let intervals = [
            ActivityInterval(kind: .studying, startedAt: midnight.addingTimeInterval(-1800), endedAt: midnight.addingTimeInterval(1800)),
            ActivityInterval(kind: .breakTime, startedAt: midnight.addingTimeInterval(1800), endedAt: midnight.addingTimeInterval(2100))
        ]

        let days = ActivityStatistics.days(from: firstDay, through: midnight, intervals: intervals, calendar: calendar)

        #expect(days.count == 2)
        #expect(days[0].studying == 1800)
        #expect(days[0].breakTime == 0)
        #expect(days[1].studying == 1800)
        #expect(days[1].breakTime == 300)
    }

    @Test
    func clipsIntervalsToRequestedDaysAndReturnsEmptyDays() throws {
        let calendar = Calendar(identifier: .gregorian)
        let start = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 20)))
        let thirdDay = try #require(calendar.date(byAdding: .day, value: 2, to: start))
        let intervals = [
            ActivityInterval(kind: .kaskasPaused, startedAt: start.addingTimeInterval(-600), endedAt: start.addingTimeInterval(600))
        ]

        let days = ActivityStatistics.days(from: start, through: thirdDay, intervals: intervals, calendar: calendar)

        #expect(days.count == 3)
        #expect(days[0].kaskasPaused == 600)
        #expect(days[1].kaskasPaused == 0)
        #expect(days[2].studying == 0)
    }
}
