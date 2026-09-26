import Foundation

/// A resolved idle interval. Dates are stored independently of the current timer
/// so a future history view can group sessions by their actual calendar day.
struct SmartPauseRecord: Codable, Equatable, Sendable {
    let focusStartedAt: Date
    let focusStoppedAt: Date
    let returnedAt: Date
    let focusedDuration: TimeInterval
}
