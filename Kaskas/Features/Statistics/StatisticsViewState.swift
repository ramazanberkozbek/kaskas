import Foundation
import Observation

/// Owned by the settings window so leaving the pane keeps its selection and data.
@MainActor
@Observable
final class StatisticsViewState {
    var period: StatisticsPeriod = .seven
    var endDate: Date
    private(set) var now: Date
    // Keep the content mounted while a new selection loads so the scroll view
    // does not collapse to the initial loading indicator and reset its offset.
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
