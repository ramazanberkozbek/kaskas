import Foundation
import Testing
@testable import Kaskas

struct DashboardSummaryTests {
    @Test
    func comparesYesterdayAtTheSameClockTimeAndKeepsTheFullDayTotal() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Istanbul"))
        let today = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 30)))
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: today))
        let now = try #require(calendar.date(bySettingHour: 12, minute: 30, second: 0, of: today))
        let morning = try #require(calendar.date(bySettingHour: 11, minute: 30, second: 0, of: yesterday))
        let afternoon = try #require(calendar.date(bySettingHour: 15, minute: 0, second: 0, of: yesterday))
        let todayStart = try #require(calendar.date(bySettingHour: 10, minute: 0, second: 0, of: today))
        let intervals = [
            ActivityInterval(kind: .studying, startedAt: morning, endedAt: morning.addingTimeInterval(2 * 3600)),
            ActivityInterval(kind: .studying, startedAt: afternoon, endedAt: afternoon.addingTimeInterval(3600)),
            ActivityInterval(kind: .studying, startedAt: todayStart, endedAt: todayStart.addingTimeInterval(1800)),
            ActivityInterval(kind: .breakTime, startedAt: todayStart, endedAt: todayStart.addingTimeInterval(3600))
        ]

        let summary = DashboardSummary.make(intervals: intervals, now: now, calendar: calendar)

        #expect(summary.today == 1800)
        #expect(summary.yesterdayAtThisTime == 3600)
        #expect(summary.yesterday == 3 * 3600)
        #expect(summary.week.count == 7)
        #expect(summary.weekTotal == 3.5 * 3600)
        #expect(summary.ranges.count == 3)
    }

    @Test
    func overlappingIntervalsAppearAsOneTimelineRange() throws {
        let calendar = Calendar(identifier: .gregorian)
        let today = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 30)))
        let now = today.addingTimeInterval(14 * 3600)
        let start = today.addingTimeInterval(9 * 3600)
        let intervals = [
            ActivityInterval(kind: .studying, startedAt: start, endedAt: start.addingTimeInterval(3600)),
            ActivityInterval(kind: .studying, startedAt: start.addingTimeInterval(1800), endedAt: start.addingTimeInterval(5400))
        ]

        let summary = DashboardSummary.make(intervals: intervals, now: now, calendar: calendar)

        #expect(summary.today == 5400)
        #expect(summary.ranges.filter(\.isToday).count == 1)
    }
}
