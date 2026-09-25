struct SessionState: Codable, Equatable, Sendable {
    let session: FocusSession
    let activeConfiguration: FocusConfiguration
    let hasShownBreakWarning: Bool

    init(
        session: FocusSession,
        activeConfiguration: FocusConfiguration,
        hasShownBreakWarning: Bool = false
    ) {
        self.session = session
        self.activeConfiguration = activeConfiguration
        self.hasShownBreakWarning = hasShownBreakWarning
    }

    private enum CodingKeys: String, CodingKey {
        case session, activeConfiguration, hasShownBreakWarning
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        session = try container.decode(FocusSession.self, forKey: .session)
        activeConfiguration = try container.decode(FocusConfiguration.self, forKey: .activeConfiguration)
        hasShownBreakWarning = try container.decodeIfPresent(
            Bool.self,
            forKey: .hasShownBreakWarning
        ) ?? false
    }
}
