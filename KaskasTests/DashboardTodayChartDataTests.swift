import Foundation
import Testing
@testable import Kaskas

struct DailyStudyChartDataTests {
    @Test func todayStopsAtTheCurrentHourAndPosition() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 4, hour: 21, minute: 10)))
        let date = calendar.startOfDay(for: now)
        let data = DailyStudyChartData.make(date: date, intervals: [], calendar: calendar)
        #expect(data.visibleHours(at: now, calendar: calendar) == 0..<22)
        #expect(!data.visibleHours(at: now, calendar: calendar).contains(23))
        #expect(abs(data.position(for: 21, at: now, calendar: calendar) - (21 + 1.0 / 6)) < 0.000001)
        #expect(data.position(for: 20, at: now, calendar: calendar) == 20.5)
        #expect(data.visibleHours(at: date, calendar: calendar) == 0..<1)
        #expect(data.position(for: 0, at: date, calendar: calendar) == 0)

        let later = now.addingTimeInterval(3600)
        #expect(data.visibleHours(at: later, calendar: calendar) == 0..<23)
        let tomorrow = try #require(calendar.date(byAdding: .day, value: 1, to: date))
        #expect(data.visibleHours(at: tomorrow, calendar: calendar) == 0..<24)
        #expect(data.position(for: 23, at: tomorrow, calendar: calendar) == 23.5)
        let future = DailyStudyChartData.make(date: tomorrow, intervals: [], calendar: calendar)
        #expect(future.visibleHours(at: now, calendar: calendar).isEmpty)
    }
}
