import Foundation

struct FocusConfiguration: Codable, Equatable, Sendable {
    var focusDuration: TimeInterval
    var microReminderInterval: TimeInterval
    var breakDuration: TimeInterval
    var snoozeDuration: TimeInterval

    init(
        focusDuration: TimeInterval = 45 * 60,
        microReminderInterval: TimeInterval = 20 * 60,
        breakDuration: TimeInterval = 5 * 60,
        snoozeDuration: TimeInterval = 5 * 60
    ) {
        self.focusDuration = max(1, focusDuration)
        self.microReminderInterval = max(1, microReminderInterval)
        self.breakDuration = max(1, breakDuration)
        self.snoozeDuration = max(1, snoozeDuration)
    }
}
