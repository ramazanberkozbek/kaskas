import Foundation
import Observation

/// Owned by the settings window so leaving the pane keeps its selection and data.
@MainActor
@Observable
final class StatisticsViewState {
    var period: StatisticsPeriod = .seven
    var endDate: Date
    private(set) var today: Date
    private(set) var now: Date
    // Keep the content mounted while a new selection loads so the scroll view
    // does not collapse to the initial loading indicator and reset its offset.
    var snapshot: StatisticsRefreshSnapshot?

    init(now: Date = Date(), calendar: Calendar = .current) {
        self.now = now
        let start = calendar.startOfDay(for: now)
        self.today = start
        self.endDate = start
    }

    func updateClock(to date: Date, calendar: Calendar = .current) {
        let previousToday = today
        now = date
        let newToday = calendar.startOfDay(for: date)
        if newToday != previousToday {
            today = newToday
        }
        if endDate == previousToday {
            endDate = newToday
        }
    }
}
