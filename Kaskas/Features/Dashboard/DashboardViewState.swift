import Foundation
import Observation

/// Keeps the dashboard's selection and last completed refresh across pane changes.
@MainActor
@Observable
final class DashboardViewState {
    // Each refresh includes both periods, so switching periods can reuse the data.
    var period: DashboardPeriod = .today
    var endDate: Date {
        didSet { if endDate != oldValue { snapshot = nil } }
    }
    private(set) var today: Date
    private(set) var now: Date
    var snapshot: DashboardRefreshSnapshot?

    init(now: Date = Date(), calendar: Calendar = .current) {
        self.now = now
        let start = calendar.startOfDay(for: now)
        self.today = start
        endDate = start
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

enum DashboardPeriod: Int {
    case today = 1
    case week = 7
}
