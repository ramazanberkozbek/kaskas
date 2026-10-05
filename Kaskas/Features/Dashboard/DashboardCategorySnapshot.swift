import Foundation

/// Derived data refreshed with the source records, independent of note/UI state.
nonisolated struct DashboardCategorySnapshot: Sendable {
    struct Session: Identifiable, Sendable {
        let value: StudySession
        let summary: StudySessionCategorySummary
        var id: String { value.id }
    }

    let usage: CategoryUsageSummary
    let sessions: [Session]

    static let empty = Self(usage: .empty, sessions: [])

    static func make(intervals: [ActivityInterval], appUsage: [AppUsageSegment], sessions: [StudySession],
                     from start: Date, to end: Date) -> Self {
        make(intervals: intervals, timeline: CategoryUsageSummary.Timeline(usage: appUsage),
             sessions: sessions, from: start, to: end)
    }

    static func make(intervals: [ActivityInterval], timeline: CategoryUsageSummary.Timeline, sessions: [StudySession],
                     from start: Date, to end: Date) -> Self {
        return Self(usage: timeline.summary(intervals: intervals, from: start, to: end),
                    sessions: sessions.map { session in
                        Session(value: session, summary: .init(usage: timeline.summary(
                            intervals: (session.effectiveSegments ?? session.segments).map {
                                ActivityInterval(kind: .studying, startedAt: $0.start, endedAt: $0.end)
                            }, from: session.startedAt, to: session.endedAt)))
                    })
    }
}
