import Foundation

nonisolated struct StudySession: Identifiable, Sendable {
    struct Segment: Identifiable, Sendable {
        let start: Date
        var end: Date

        var id: Date { start }
        var duration: TimeInterval { end.timeIntervalSince(start) }
    }

    let intervals: [ActivityInterval]
    let segments: [Segment]

    var id: String { intervals[0].sessionKey }
    var startedAt: Date { segments[0].start }
    var endedAt: Date { segments[segments.count - 1].end }
    var focusedDuration: TimeInterval { segments.reduce(0) { $0 + $1.duration } }
    var interruptionCount: Int {
        zip(segments, segments.dropFirst()).reduce(0) { count, pair in
            count + (pair.1.start.timeIntervalSince(pair.0.end) >= StudySessionGrouping.minimumCountedInterruption ? 1 : 0)
        }
    }

    func isOngoing(startedAt activeStart: Date?) -> Bool {
        guard let activeStart else { return false }
        return intervals.contains { $0.startedAt == activeStart }
    }

    func isVisible(showShortSessions: Bool, hasAnnotation: Bool, activeStartedAt: Date?) -> Bool {
        if hasAnnotation { return true }
        if isOngoing(startedAt: activeStartedAt) { return focusedDuration >= 60 }
        return showShortSessions || focusedDuration >= StudySessionGrouping.minimumDefaultDuration
    }
}

nonisolated enum StudySessionGrouping {
    static let maximumInterruption: TimeInterval = 4 * 60
    static let minimumCountedInterruption: TimeInterval = 30
    static let minimumDefaultDuration: TimeInterval = 5 * 60

    static func group(
        _ intervals: [ActivityInterval],
        breakEntries: [BreakHistoryEntry] = []
    ) -> [StudySession] {
        let studying = intervals
            .filter { $0.kind == .studying }
            .sorted {
                if $0.startedAt == $1.startedAt { return $0.endedAt < $1.endedAt }
                return $0.startedAt < $1.startedAt
            }

        var result: [StudySession] = []
        var sources: [ActivityInterval] = []
        var segments: [StudySession.Segment] = []
        let actualBreaks = breakEntries.filter { $0.isSessionBoundary }

        func finish() {
            guard !sources.isEmpty else { return }
            result.append(StudySession(intervals: sources, segments: segments))
            sources = []
            segments = []
        }

        for interval in studying {
            if let last = segments.last,
               (interval.startedAt.timeIntervalSince(last.end) >= maximumInterruption
                || actualBreaks.contains { entry in
                    guard let breakStart = entry.startedAt else { return false }
                    return breakStart >= last.end
                        && entry.occurredAt <= interval.startedAt
                }) {
                finish()
            }

            sources.append(interval)
            if let last = segments.indices.last, interval.startedAt <= segments[last].end {
                segments[last].end = max(segments[last].end, interval.endedAt)
            } else {
                segments.append(.init(start: interval.startedAt, end: interval.endedAt))
            }
        }
        finish()
        return result
    }
}
