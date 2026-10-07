import Foundation
import Testing
@testable import Kaskas

@MainActor
struct StatisticsViewStateTests {
    @Test(arguments: [false, true])
    func returningAfterMidnightFollowsTodayButPreservesHistoricalSelection(_ historical: Bool) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Istanbul"))
        let before = try #require(calendar.date(from: DateComponents(year: 2026, month: 12, day: 31, hour: 23)))
        let after = before.addingTimeInterval(2 * 3600)
        let state = StatisticsViewState(now: before, calendar: calendar)
        state.period = .thirty
        if historical {
            state.endDate = try #require(calendar.date(byAdding: .day, value: -7, to: state.endDate))
        }
        let selectedDate = state.endDate
        state.snapshot = snapshot(on: selectedDate, calendar: calendar)

        // Re-entering the pane refreshes its clock after time spent elsewhere.
        state.updateClock(to: after, calendar: calendar)

        #expect(state.now == after)
        #expect(state.period == .thirty)
        #expect(state.endDate == (historical ? selectedDate : calendar.startOfDay(for: after)))
        if historical {
            #expect(state.snapshot?.chart.distributionDays.first?.studying == 3600)
        } else {
            #expect(state.snapshot == nil)
        }
    }

    @Test
    func sameDayReturnKeepsLoadedDataUntilSelectionChanges() throws {
        let calendar = Calendar.current
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 7, hour: 12)))
        let state = StatisticsViewState(now: now, calendar: calendar)
        state.snapshot = snapshot(on: state.endDate, calendar: calendar)

        state.updateClock(to: now.addingTimeInterval(60), calendar: calendar)
        #expect(state.snapshot?.chart.distributionDays.first?.studying == 3600)

        state.period = .day
        #expect(state.snapshot == nil)
        state.snapshot = snapshot(on: state.endDate, calendar: calendar)
        state.endDate = try #require(calendar.date(byAdding: .day, value: -1, to: state.endDate))
        #expect(state.snapshot == nil)
    }

    private func snapshot(on day: Date, calendar: Calendar) -> StatisticsRefreshSnapshot {
        let interval = ActivityInterval(kind: .studying, startedAt: day,
                                        endedAt: day.addingTimeInterval(3600))
        return StatisticsRefreshSnapshot(categories: .empty,
            chart: .make(intervals: [interval], trendWindow: (day, day),
                         distributionWindow: (day, day), hourlyWindow: (day, day),
                         year: calendar.component(.year, from: day), calendar: calendar))
    }
}
