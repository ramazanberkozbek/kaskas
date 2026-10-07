import Foundation
import Testing
@testable import Kaskas

@MainActor
struct DashboardViewStateTests {
    @Test
    func sameDayReturnAndPeriodSwitchKeepChartsCategoriesAndSessions() async throws {
        let calendar = calendar()
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 7, hour: 12)))
        let state = DashboardViewState(now: now, calendar: calendar)
        state.snapshot = try await snapshot(on: state.endDate, calendar: calendar)

        state.updateClock(to: now.addingTimeInterval(60), calendar: calendar)
        state.period = .week
        let cached = try #require(state.snapshot)
        #expect(cached.chart.days.reduce(0) { $0 + $1.studying } == 7200)
        #expect(cached.week.usage.total == 7200)
        #expect(cached.week.sessions.count == 2)

        state.period = .today
        #expect(state.snapshot?.day.usage.total == 3600)
        #expect(state.snapshot?.day.sessions.count == 1)
        #expect(state.snapshot?.chart.today.todayHours.reduce(0, +) == 1)

        state.endDate = try #require(calendar.date(byAdding: .day, value: -1, to: state.endDate))
        #expect(state.snapshot == nil)
    }

    @Test(arguments: [false, true])
    func returningAfterMidnightFollowsTodayButPreservesHistoricalSelection(_ historical: Bool) async throws {
        let calendar = calendar()
        let before = try #require(calendar.date(from: DateComponents(year: 2026, month: 12, day: 31, hour: 23)))
        let after = before.addingTimeInterval(2 * 3600)
        let state = DashboardViewState(now: before, calendar: calendar)
        state.period = .week
        if historical {
            state.endDate = try #require(calendar.date(byAdding: .day, value: -7, to: state.endDate))
        }
        let selectedDate = state.endDate
        state.snapshot = try await snapshot(on: selectedDate, calendar: calendar)

        state.updateClock(to: after, calendar: calendar)

        #expect(state.now == after)
        #expect(state.period == .week)
        #expect(state.endDate == (historical ? selectedDate : calendar.startOfDay(for: after)))
        if historical {
            #expect(state.snapshot?.week.usage.total == 7200)
        } else {
            #expect(state.snapshot == nil)
        }
    }

    private func calendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return calendar
    }

    private func snapshot(on day: Date, calendar: Calendar) async throws -> DashboardRefreshSnapshot {
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: day))
        let weekStart = try #require(calendar.date(byAdding: .day, value: -6, to: day))
        let end = try #require(calendar.date(byAdding: .day, value: 1, to: day))
        let intervals = [yesterday, day].map {
            ActivityInterval(kind: .studying, startedAt: $0.addingTimeInterval(9 * 3600),
                             endedAt: $0.addingTimeInterval(10 * 3600))
        }
        return try await DashboardRefreshSnapshot.make(intervals: intervals, usage: [], breaks: [],
            date: day, weekStart: weekStart, sessionEnd: end, calendar: calendar)
    }
}
