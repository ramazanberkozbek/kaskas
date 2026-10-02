import Foundation
import Testing
@testable import Kaskas

struct ActivityChartSnapshotTests {
    private func calendar(_ zone: String = "Europe/Istanbul") -> Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: zone)!
        return value
    }

    @Test func trendAverageIncludesTheSixPrecedingDaysAndEmptyDays() throws {
        let calendar = calendar()
        let start = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 20)))
        let prior = try #require(calendar.date(byAdding: .day, value: -6, to: start))
        let next = try #require(calendar.date(byAdding: .day, value: 1, to: start))
        let intervals = [ActivityInterval(kind: .studying, startedAt: prior, endedAt: prior.addingTimeInterval(7 * 3600)),
            ActivityInterval(kind: .studying, startedAt: start, endedAt: start.addingTimeInterval(3600))]
        let days = ActivityStatistics.days(from: start, through: next, intervals: intervals, calendar: calendar)
        let data = StudyTrendData.make(days: days, intervals: intervals, calendar: calendar)
        #expect(data.points.map(\.date) == [start, next])
        #expect(data.points.map(\.hours) == [1, 0])
        #expect(abs(data.points[0].averageHours - 8.0 / 7) < 0.000001)
        #expect(abs(data.points[1].averageHours - 1.0 / 7) < 0.000001)
        #expect(StudyTrendData.make(days: [], intervals: intervals).points.isEmpty)
    }

    @Test func dashboardRefreshMovesItsWindowAndPreservesThePreviousSnapshot() throws {
        let calendar = calendar()
        let day = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 25)))
        let tomorrow = try #require(calendar.date(byAdding: .day, value: 1, to: day))
        let weekStart = try #require(calendar.date(byAdding: .day, value: -6, to: day))
        let first = ActivityInterval(kind: .studying, startedAt: day.addingTimeInterval(9 * 3600), endedAt: day.addingTimeInterval(9.5 * 3600))
        let extended = ActivityInterval(kind: .studying, startedAt: first.startedAt, endedAt: day.addingTimeInterval(10 * 3600))
        let before = DashboardChartSnapshot.make(intervals: [first], date: day, weekStart: weekStart, calendar: calendar)
        let after = DashboardChartSnapshot.make(intervals: [extended], date: tomorrow,
            weekStart: calendar.date(byAdding: .day, value: 1, to: weekStart)!, calendar: calendar)
        #expect(before.days.count == 7)
        #expect(before.days.last?.studying == 1800)
        #expect(before.today.todayHours[9] == 0.5)
        #expect(after.today.date == tomorrow)
        #expect(after.today.todayHours.reduce(0, +) == 0)
        #expect(after.today.yesterdayHours[9] == 1)
        #expect(after.days.reduce(0) { $0 + $1.studying } == 3600)
        #expect(after.trend.points.map(\.date) == after.days.map(\.date))
        #expect(before.today.todayHours[9] == 0.5)
    }

    @Test func statisticsKeepsIndependentRangesAndActivityKinds() throws {
        let calendar = calendar()
        let day = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 25)))
        let tomorrow = try #require(calendar.date(byAdding: .day, value: 1, to: day))
        let nextYear = try #require(calendar.date(from: DateComponents(year: 2027, month: 1, day: 1)))
        let a = day.addingTimeInterval(9 * 3600)
        let intervals = [ActivityInterval(kind: .studying, startedAt: a, endedAt: a.addingTimeInterval(3600)),
            ActivityInterval(kind: .studying, startedAt: a.addingTimeInterval(1800), endedAt: a.addingTimeInterval(5400)),
            ActivityInterval(kind: .breakTime, startedAt: a, endedAt: a.addingTimeInterval(600)),
            ActivityInterval(kind: .meeting, startedAt: tomorrow, endedAt: tomorrow.addingTimeInterval(900)),
            ActivityInterval(kind: .studying, startedAt: nextYear, endedAt: nextYear.addingTimeInterval(3600))]
        let snapshot = StatisticsChartSnapshot.make(intervals: intervals, now: day,
            trendWindow: (day, tomorrow), distributionWindow: (tomorrow, tomorrow),
            hourlyWindow: (day, day), year: 2026, calendar: calendar)
        #expect(snapshot.today.studying == 5400)
        #expect(snapshot.today.breakTime == 600)
        #expect(snapshot.trend.points.map(\.hours) == [1.5, 0])
        #expect(snapshot.distributionDays.count == 1)
        #expect(snapshot.distributionDays[0].meeting == 900)
        #expect(snapshot.distributionPoints.count == ActivityKind.allCases.count)
        #expect(snapshot.distributionPoints.first { $0.kind == .meeting }?.hours == 0.25)
        #expect(snapshot.hourlyPoints.count == 24)
        #expect(snapshot.hourlyPoints.first { $0.hour == 9 }?.minutes == 60)
        #expect(snapshot.hourlyPoints.first { $0.hour == 10 }?.minutes == 30)
        #expect(snapshot.year.activityByDate.count == 365)
        #expect(snapshot.year.activityByDate.values.reduce(0, +) == 5400)
        #expect(Set(snapshot.year.weeks.flatMap { $0 }).count == snapshot.year.weeks.flatMap { $0 }.count)
        #expect(snapshot.year.weeks.allSatisfy { $0.count == 7 })
    }

    @Test(arguments: [(3, 8, 23, 0.0), (11, 1, 25, 120.0)])
    func hourlyChartsRespectDSTAndRefreshTheirScale(_ month: Int, _ day: Int, _ hours: Int, _ repeatedHour: Double) throws {
        let calendar = calendar("America/New_York")
        let start = try #require(calendar.date(from: DateComponents(year: 2026, month: month, day: day)))
        let end = try #require(calendar.date(byAdding: .day, value: 1, to: start))
        #expect(end.timeIntervalSince(start) == Double(hours) * 3600)
        let intervals = [ActivityInterval(kind: .studying, startedAt: start, endedAt: end)]
        let snapshot = StatisticsChartSnapshot.make(intervals: intervals, now: start,
            trendWindow: (start, start), distributionWindow: (start, start), hourlyWindow: (start, start), year: 2026, calendar: calendar)
        #expect(snapshot.today.studying == Double(hours) * 3600)
        #expect(snapshot.hourlyPoints.reduce(0) { $0 + $1.minutes } == Double(hours) * 60)
        if hours == 23 { #expect(snapshot.hourlyPoints.first { $0.hour == 2 }?.minutes == repeatedHour) }
        else { #expect(snapshot.hourlyPoints.first { $0.hour == 1 }?.minutes == repeatedHour) }
        #expect(snapshot.hourlyUpperBound == (hours == 25 ? 120 : 60))
        let daily = DashboardTodayChartData.make(date: start, intervals: intervals, calendar: calendar)
        #expect(daily.todayHours.reduce(0, +) == Double(hours))
        #expect(daily.yesterdayHours.reduce(0, +) == 0)
    }

    @Test func yearSelectionReplacesTheGridAndTotalsIncludingLeapDay() throws {
        let calendar = calendar()
        let leapDay = try #require(calendar.date(from: DateComponents(year: 2024, month: 2, day: 29)))
        let days = [DailyActivity(date: leapDay, studying: 1800)]
        let leap = YearHeatmapData.make(year: 2024, days: days, calendar: calendar)
        let normal = YearHeatmapData.make(year: 2025, days: [], calendar: calendar)
        #expect(leap.weeks.flatMap { $0 }.contains(leapDay))
        #expect(leap.activityByDate[leapDay] == 1800)
        #expect(!normal.weeks.flatMap { $0 }.contains(leapDay))
        #expect(normal.activityByDate.isEmpty)
    }
}
