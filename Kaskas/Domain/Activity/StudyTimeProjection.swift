import Foundation

/// Reports share this projection; the original timeline still drives break timing
/// and stable session/annotation identity. Exclusions are never inferred from gaps.
nonisolated struct StudyTimeProjection: Sendable {
    private struct Range: Sendable {
        let start: Date
        var end: Date
    }

    let intervals: [ActivityInterval]
    let timeline: CategoryUsageSummary.Timeline
    var usage: [AppUsageSegment] { timeline.segments }
    private let excludedRanges: [Range]

    init(intervals: [ActivityInterval], usage: [AppUsageSegment],
         excluded: [ExcludedUsageInterval], exclusions: AppExclusionSnapshot) {
        let usageTimeline = CategoryUsageSummary.Timeline(usage: usage)
        var historical: [Range] = []
        if exclusions.identifiers.isEmpty {
            timeline = usageTimeline
        } else {
            // Identify historical exclusions and retain the other winner slices
            // in one pass, without normalizing each app identifier twice.
            timeline = usageTimeline.filter { segment in
                guard exclusions.contains(segment.app) else { return true }
                historical.append(Range(start: segment.startedAt, end: segment.endedAt))
                return false
            }
        }
        let ordered = (historical + excluded.map { Range(start: $0.startedAt, end: $0.endedAt) })
            .filter { $0.end > $0.start }.sorted { $0.start < $1.start }
        var merged: [Range] = []
        for range in ordered {
            if let last = merged.indices.last, range.start <= merged[last].end {
                merged[last].end = max(merged[last].end, range.end)
            } else { merged.append(range) }
        }
        excludedRanges = merged
        self.intervals = merged.isEmpty ? intervals : intervals.flatMap { interval -> [ActivityInterval] in
            guard interval.kind == .studying else { return [interval] }
            return Self.subtract(from: interval.startedAt, to: interval.endedAt, exclusions: merged).map {
                ActivityInterval(kind: .studying, startedAt: $0.start, endedAt: $0.end)
            }
        }
    }

    /// Group before projection: an excluded visit is not a new session boundary.
    func session(_ original: StudySession) -> StudySession? {
        let net = original.segments.flatMap {
            Self.subtract(from: $0.start, to: $0.end, exclusions: excludedRanges)
                .map { StudySession.Segment(start: $0.start, end: $0.end) }
        }
        guard !net.isEmpty else { return nil }
        var session = original
        session.effectiveSegments = net
        return session
    }

    private static func subtract(from start: Date, to end: Date, exclusions: [Range]) -> [Range] {
        guard end > start else { return [] }
        // Exclusion ranges are disjoint and their ends are sorted too.
        var lower = 0, upper = exclusions.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if exclusions[middle].end <= start { lower = middle + 1 } else { upper = middle }
        }
        var cursor = start
        var result: [Range] = []
        for index in lower..<exclusions.count {
            let range = exclusions[index]
            guard range.start < end else { break }
            if range.start > cursor { result.append(.init(start: cursor, end: min(range.start, end))) }
            cursor = max(cursor, range.end)
            if cursor >= end { break }
        }
        if cursor < end { result.append(.init(start: cursor, end: end)) }
        return result
    }
}
