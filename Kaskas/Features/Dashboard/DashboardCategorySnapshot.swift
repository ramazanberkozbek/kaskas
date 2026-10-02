import Foundation

/// Derived data refreshed with the source records, independent of note/UI state.
struct DashboardCategorySnapshot {
    struct Session: Identifiable {
        let value: StudySession
        let summary: StudySessionCategorySummary
        var id: String { value.id }
    }

    let usage: CategoryUsageSummary
    let sessions: [Session]

    static let empty = Self(usage: .empty, sessions: [])

    static func make(intervals: [ActivityInterval], appUsage: [AppUsageSegment], sessions: [StudySession],
                     from start: Date, to end: Date) -> Self {
        let timeline = CategoryUsageSummary.Timeline(usage: appUsage)
        return Self(usage: timeline.summary(intervals: intervals, from: start, to: end),
                    sessions: sessions.map { session in
                        Session(value: session, summary: .init(usage: timeline.summary(
                            intervals: session.intervals, from: session.startedAt, to: session.endedAt)))
                    })
    }
}
