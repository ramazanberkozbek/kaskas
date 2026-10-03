import Foundation

struct FocusSession: Codable, Equatable, Sendable {
    var phase: SessionPhase
    var startedAt: Date
    var endsAt: Date
    var nextMicroReminderAt: Date?
}
