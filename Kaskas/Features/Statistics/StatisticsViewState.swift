import Foundation
import Observation

/// Owned by the settings window so leaving the pane keeps its selection and data.
@MainActor
@Observable
final class StatisticsViewState {
    var period: StatisticsPeriod = .seven {
        didSet { if period != oldValue { snapshot = nil } }
    }
    var endDate: Date {
        didSet { if endDate != oldValue { snapshot = nil } }
    }
    private(set) var now: Date
    var snapshot: StatisticsRefreshSnapshot?

    init(now: Date = Date(), calendar: Calendar = .current) {
        self.now = now
        endDate = calendar.startOfDay(for: now)
    }

    func updateClock(to date: Date, calendar: Calendar = .current) {
        let previousToday = calendar.startOfDay(for: now)
        now = date
        if endDate == previousToday {
            endDate = calendar.startOfDay(for: date)
        }
    }
}
