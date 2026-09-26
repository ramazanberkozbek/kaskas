import Foundation

struct SessionState: Codable, Equatable, Sendable {
    let session: FocusSession
    let activeConfiguration: FocusConfiguration
    let hasShownBreakWarning: Bool
    let completedBreaks: Int
    let completedBreaksDay: Date?
    let consecutiveSkippedBreaks: Int
    let meetingPauseStartedAt: Date?
    let systemPauseStartedAt: Date?

    init(
        session: FocusSession,
        activeConfiguration: FocusConfiguration,
        hasShownBreakWarning: Bool = false,
        completedBreaks: Int = 0,
        completedBreaksDay: Date? = nil,
        consecutiveSkippedBreaks: Int = 0,
        meetingPauseStartedAt: Date? = nil,
        systemPauseStartedAt: Date? = nil
    ) {
        self.session = session
        self.activeConfiguration = activeConfiguration
        self.hasShownBreakWarning = hasShownBreakWarning
        self.completedBreaks = completedBreaks
        self.completedBreaksDay = completedBreaksDay
        self.consecutiveSkippedBreaks = consecutiveSkippedBreaks
        self.meetingPauseStartedAt = meetingPauseStartedAt
        self.systemPauseStartedAt = systemPauseStartedAt
    }

    private enum CodingKeys: String, CodingKey {
        case session, activeConfiguration, hasShownBreakWarning, completedBreaks, completedBreaksDay
        case consecutiveSkippedBreaks
        case meetingPauseStartedAt
        case systemPauseStartedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        session = try container.decode(FocusSession.self, forKey: .session)
        activeConfiguration = try container.decode(FocusConfiguration.self, forKey: .activeConfiguration)
        hasShownBreakWarning = try container.decodeIfPresent(
            Bool.self,
            forKey: .hasShownBreakWarning
        ) ?? false
        completedBreaks = try container.decodeIfPresent(Int.self, forKey: .completedBreaks) ?? 0
        completedBreaksDay = try container.decodeIfPresent(Date.self, forKey: .completedBreaksDay)
        consecutiveSkippedBreaks = try container.decodeIfPresent(Int.self, forKey: .consecutiveSkippedBreaks) ?? 0
        meetingPauseStartedAt = try container.decodeIfPresent(Date.self, forKey: .meetingPauseStartedAt)
        systemPauseStartedAt = try container.decodeIfPresent(Date.self, forKey: .systemPauseStartedAt)
    }
}
