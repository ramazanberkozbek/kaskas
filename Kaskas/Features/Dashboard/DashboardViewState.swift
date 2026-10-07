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
    private(set) var now: Date
    var snapshot: DashboardRefreshSnapshot?

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

enum DashboardPeriod: Int {
    case today = 1
    case week = 7
}
