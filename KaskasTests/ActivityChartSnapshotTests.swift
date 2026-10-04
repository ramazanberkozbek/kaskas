import Foundation
import Testing
@testable import Kaskas

struct ActivityChartSnapshotTests {
    private func calendar(_ zone: String = "Europe/Istanbul") -> Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: zone)!
        return value
    }

    @Test func commonPeriodKeepsChartsAndCategoriesAlignedAcrossYearBoundaries() throws {
        let calendar = calendar()
        let end = try #require(calendar.date(from: DateComponents(year: 2026, month: 1, day: 3, hour: 15)))
        for period in StatisticsPeriod.allCases {
            let window = period.window(endingAt: end, calendar: calendar)
            let exclusiveEnd = try #require(calendar.date(byAdding: .day, value: 1, to: window.end))
            let intervals = [ActivityInterval(kind: .studying,
                startedAt: window.start.addingTimeInterval(-3600), endedAt: window.start.addingTimeInterval(3600)),
                ActivityInterval(kind: .studying, startedAt: exclusiveEnd.addingTimeInterval(-1800),
                                 endedAt: exclusiveEnd.addingTimeInterval(1800))]
            let snapshot = StatisticsChartSnapshot.make(intervals: intervals,
                trendWindow: window, distributionWindow: window, hourlyWindow: window,
                year: 2026, calendar: calendar, period: period)
            let categories = CategoryUsageSummary.make(intervals: intervals, usage: [], from: window.start, to: exclusiveEnd)
            #expect(snapshot.distributionDays.count == calendar.dateComponents([.day], from: window.start, to: exclusiveEnd).day)
            #expect(snapshot.trend.points.map(\.date) == snapshot.distributionBuckets.map(\.date))
            #expect(snapshot.trend.resolution == (period == .year ? .month : .day))
            #expect(snapshot.distributionBuckets.reduce(0) { $0 + $1.duration(for: .studying) } == categories.total)
            #expect(snapshot.hourlyDays.map(\.date) == snapshot.distributionDays.map(\.date))
            #expect(snapshot.distributionDays.reduce(0) { $0 + $1.studying } == categories.total)
            #expect(categories.total == 5400)
        }
    }

    @Test func calendarPeriodsAndLabelsFollowTheSelectedDate() throws {
        let calendar = calendar()
        let date = try #require(calendar.date(from: DateComponents(year: 2026, month: 2, day: 19)))
        let locale = Locale(identifier: "tr_TR")
        #expect(StatisticsPeriod.day.rangeLabel(endingAt: date, locale: locale, calendar: calendar) == "Perşembe 19 Şubat")
        #expect(StatisticsPeriod.seven.rangeLabel(endingAt: date, locale: locale, calendar: calendar) == "13 Şubat–19 Şubat 2026")
        #expect(StatisticsPeriod.thirty.rangeLabel(endingAt: date, locale: locale, calendar: calendar) == "Şubat 2026")
        #expect(StatisticsPeriod.year.rangeLabel(endingAt: date, locale: locale, calendar: calendar) == "2026")
        let month = StatisticsPeriod.thirty.window(endingAt: date, calendar: calendar)
        #expect(calendar.component(.day, from: month.start) == 1)
        #expect(calendar.component(.day, from: month.end) == 28)
        let leapDate = try #require(calendar.date(from: DateComponents(year: 2024, month: 2, day: 29)))
        let year = StatisticsPeriod.year.window(endingAt: leapDate, calendar: calendar)
        #expect(calendar.dateComponents([.day], from: year.start, to: year.end).day == 365)
        let previous = StatisticsPeriod.year.shiftedDate(leapDate, by: -1, calendar: calendar)
        #expect(calendar.component(.year, from: previous) == 2023)
        #expect(calendar.component(.day, from: previous) == 28)
        let january = StatisticsPeriod.thirty.shiftedDate(date, by: -1, calendar: calendar)
        #expect(calendar.component(.month, from: january) == 1)
    }

    @Test func dailyTrendMatchesDashboardAcrossTheYearBoundary() throws {
        let calendar = calendar()
        let date = try #require(calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)))
        let previous = try #require(calendar.date(byAdding: .day, value: -1, to: date))
        let intervals = [
            ActivityInterval(kind: .studying, startedAt: previous.addingTimeInterval(23 * 3600),
                             endedAt: date.addingTimeInterval(1800)),
            ActivityInterval(kind: .studying, startedAt: date.addingTimeInterval(1800),
                             endedAt: date.addingTimeInterval(3600)),
            ActivityInterval(kind: .breakTime, startedAt: date.addingTimeInterval(9 * 3600),
                             endedAt: date.addingTimeInterval(10 * 3600))
        ]
        let window = StatisticsPeriod.day.window(endingAt: date, calendar: calendar)
        let statistics = StatisticsChartSnapshot.make(intervals: intervals, trendWindow: window,
            distributionWindow: window, hourlyWindow: window, year: 2026, calendar: calendar)
        let dashboard = DashboardChartSnapshot.make(intervals: intervals, date: date,
            weekStart: previous, calendar: calendar)
        #expect(statistics.dailyTrend.date == date)
        #expect(statistics.dailyTrend.todayHours == dashboard.today.todayHours)
        #expect(statistics.dailyTrend.yesterdayHours == dashboard.today.yesterdayHours)
        #expect(statistics.dailyTrend.todayHours[0] == 1)
        #expect(statistics.dailyTrend.yesterdayHours[23] == 1)
        #expect(statistics.dailyTrend.todayHours[9] == 0)
        #expect(statistics.dailyTrend.currentLabelKey(at: date, calendar: calendar) == "dashboard.today")
        #expect(statistics.dailyTrend.previousLabelKey(at: date, calendar: calendar) == "dashboard.yesterday")
        let tomorrow = try #require(calendar.date(byAdding: .day, value: 1, to: date))
        #expect(statistics.dailyTrend.currentLabelKey(at: tomorrow, calendar: calendar) == "dashboard.day.selected")
        #expect(statistics.dailyTrend.previousLabelKey(at: tomorrow, calendar: calendar) == "dashboard.day.previous")
        #expect(statistics.distributionDays.count == 1)
        #expect(statistics.distributionDays[0].studying == 3600)
    }

    @Test(arguments: [2024, 2026])
    func yearlyChartsUseMonthlyTotalsWithoutChangingSummaryOrHourlyAverages(_ year: Int) throws {
        let calendar = calendar()
        let start = try #require(calendar.date(from: DateComponents(year: year, month: 1, day: 1)))
        let januaryEnd = try #require(calendar.date(from: DateComponents(year: year, month: 1, day: 3)))
        let february = try #require(calendar.date(from: DateComponents(year: year, month: 2, day: 1)))
        let end = try #require(calendar.date(from: DateComponents(year: year, month: 10, day: 4)))
        let intervals = [
            ActivityInterval(kind: .studying, startedAt: start, endedAt: januaryEnd),
            ActivityInterval(kind: .breakTime, startedAt: february, endedAt: february.addingTimeInterval(1800)),
            ActivityInterval(kind: .studying, startedAt: end, endedAt: end.addingTimeInterval(3600))
        ]
        let snapshot = StatisticsChartSnapshot.make(intervals: intervals,
            trendWindow: (start, end), distributionWindow: (start, end), hourlyWindow: (start, end),
            year: year, calendar: calendar, period: .year)
        #expect(snapshot.trend.resolution == .month)
        #expect(snapshot.trend.points.count == 10)
        #expect(snapshot.distributionBuckets.count == 10)
        #expect(snapshot.distributionPoints.count == 10 * ActivityKind.allCases.count)
        #expect(snapshot.trend.points.map { calendar.component(.month, from: $0.date) } == Array(1...10))
        #expect(snapshot.trend.points[0].hours == 48)
        #expect(snapshot.trend.points[1].hours == 0)
        #expect(snapshot.trend.points[9].hours == 1)
        #expect(snapshot.distributionBuckets[0].duration(for: .studying) == 48 * 3600)
        #expect(snapshot.distributionBuckets[1].duration(for: .breakTime) == 1800)
        #expect(snapshot.distributionBuckets[2].total == 0)
        let exclusiveEnd = try #require(calendar.date(byAdding: .day, value: 1, to: end))
        let categories = CategoryUsageSummary.make(intervals: intervals, usage: [], from: start, to: exclusiveEnd)
        #expect(snapshot.trend.points.reduce(0) { $0 + $1.hours } * 3600 == categories.total)
        #expect(snapshot.distributionDays.reduce(0) { $0 + $1.studying } == categories.total)
        #expect(abs(snapshot.averageHourlyPoints.reduce(0) { $0 + $1.minutes }
                    - categories.total / 60 / Double(snapshot.hourlyDays.count)) < 0.000001)
        let domain = ActivityChartResolution.month.domain(for: snapshot.trend.points.map(\.date), calendar: calendar)
        #expect(domain.lowerBound == start)
        #expect(calendar.component(.year, from: domain.upperBound) == year + 1)
        #expect(calendar.component(.month, from: domain.upperBound) == 1)
        let fullWindow = StatisticsPeriod.year.window(endingAt: end, calendar: calendar)
        let full = StatisticsChartSnapshot.make(intervals: intervals, trendWindow: fullWindow,
            distributionWindow: fullWindow, hourlyWindow: fullWindow, year: year, calendar: calendar, period: .year)
        #expect(full.trend.points.count == 12)
        #expect(full.distributionBuckets.count == 12)
        #expect(full.distributionDays.count == (year == 2024 ? 366 : 365))
    }

    @Test func monthlyHourlyAverageIncludesAllThirtyDaysIncludingEmptyDays() throws {
        let calendar = calendar()
        let end = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 30)))
        let window = StatisticsPeriod.thirty.window(endingAt: end, calendar: calendar)
        let start = window.start.addingTimeInterval(9 * 3600)
        let intervals = [ActivityInterval(kind: .studying, startedAt: start, endedAt: start.addingTimeInterval(3600))]
        let snapshot = StatisticsChartSnapshot.make(intervals: intervals,
            trendWindow: window, distributionWindow: window, hourlyWindow: window, year: 2026, calendar: calendar)
        #expect(snapshot.averageHourlyPoints.count == 24)
        #expect(snapshot.averageHourlyPoints.first { $0.hour == 9 }?.minutes == 2)
        #expect(snapshot.averageHourlyPoints.reduce(0) { $0 + $1.minutes } == 2)
        #expect(StatisticsChartSnapshot.empty.averageHourlyPoints.isEmpty)
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
        let snapshot = StatisticsChartSnapshot.make(intervals: intervals,
            trendWindow: (day, tomorrow), distributionWindow: (tomorrow, tomorrow),
            hourlyWindow: (day, day), year: 2026, calendar: calendar)
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
        let snapshot = StatisticsChartSnapshot.make(intervals: intervals,
            trendWindow: (start, start), distributionWindow: (start, start), hourlyWindow: (start, start), year: 2026, calendar: calendar)
        #expect(snapshot.hourlyPoints.reduce(0) { $0 + $1.minutes } == Double(hours) * 60)
        if hours == 23 { #expect(snapshot.hourlyPoints.first { $0.hour == 2 }?.minutes == repeatedHour) }
        else { #expect(snapshot.hourlyPoints.first { $0.hour == 1 }?.minutes == repeatedHour) }
        let daily = DailyStudyChartData.make(date: start, intervals: intervals, calendar: calendar)
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
