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

    @Test
    func focusMinutesByHourSplitsAtHoursAndMidnightAndIgnoresBreaks() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Istanbul"))
        let day = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 25)))
        let morning = try #require(calendar.date(bySettingHour: 9, minute: 45, second: 0, of: day))
        let evening = try #require(calendar.date(bySettingHour: 23, minute: 50, second: 0, of: day))
        let intervals = [
            ActivityInterval(kind: .studying, startedAt: morning, endedAt: morning.addingTimeInterval(30 * 60)),
            ActivityInterval(kind: .breakTime, startedAt: morning, endedAt: morning.addingTimeInterval(10 * 60)),
            ActivityInterval(kind: .studying, startedAt: evening, endedAt: evening.addingTimeInterval(20 * 60))
        ]

        let firstDay = ActivityStatistics.focusMinutesByHour(on: day, intervals: intervals, calendar: calendar)
        let nextDay = try #require(calendar.date(byAdding: .day, value: 1, to: day))
        let secondDay = ActivityStatistics.focusMinutesByHour(on: nextDay, intervals: intervals, calendar: calendar)

        #expect(firstDay.count == 24)
        #expect(firstDay[9] == 15)
        #expect(firstDay[10] == 15)
        #expect(firstDay[23] == 10)
        #expect(firstDay.reduce(0, +) == 40)
        #expect(secondDay[0] == 10)
    }

    @Test
    func overlappingFocusRecordsCountElapsedMinutesOnlyOnce() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Istanbul"))
        let day = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 26)))
        let hour = try #require(calendar.date(bySettingHour: 19, minute: 0, second: 0, of: day))
        let intervals = [
            ActivityInterval(kind: .studying, startedAt: hour, endedAt: hour.addingTimeInterval(45 * 60)),
            ActivityInterval(kind: .studying, startedAt: hour.addingTimeInterval(15 * 60), endedAt: hour.addingTimeInterval(60 * 60)),
            ActivityInterval(kind: .studying, startedAt: hour.addingTimeInterval(15 * 60), endedAt: hour.addingTimeInterval(60 * 60))
        ]

        let minutes = ActivityStatistics.focusMinutesByHour(on: day, intervals: intervals, calendar: calendar)
        let summary = ActivityStatistics.days(from: day, through: day, intervals: intervals, calendar: calendar)

        #expect(minutes[19] == 60)
        #expect(minutes.reduce(0, +) == 60)
        #expect(summary.first?.studying == 3600)
    }
}
