import Foundation

nonisolated struct CategoryUsageSummary: Equatable, Sendable {
    struct Entry: Equatable, Identifiable, Sendable {
        let categoryID: String
        let duration: TimeInterval
        var id: String { categoryID }
    }

    let entries: [Entry]
    let undetected: TimeInterval
    let total: TimeInterval

    /// Clips to the authoritative study timeline, including retrospective idle edits.
    /// Overlapping/replayed usage is counted once, with a deterministic first-record winner.
    static func make(intervals: [ActivityInterval], usage: [AppUsageSegment], from start: Date, to end: Date) -> Self {
        var ranges: [(start: Date, end: Date)] = []
        for interval in intervals.filter({ $0.kind == .studying && $0.startedAt < end && $0.endedAt > start })
            .sorted(by: { $0.startedAt < $1.startedAt }) {
            let a = max(start, interval.startedAt), b = min(end, interval.endedAt)
            guard b > a else { continue }
            if let last = ranges.indices.last, a <= ranges[last].end { ranges[last].end = max(ranges[last].end, b) }
            else { ranges.append((a, b)) }
        }
        let segments = usage.sorted {
            if $0.startedAt == $1.startedAt { return $0.id.uuidString < $1.id.uuidString }
            return $0.startedAt < $1.startedAt
        }
        var totals: [String: TimeInterval] = [:]
        for range in ranges {
            var cursor = range.start
            for segment in segments where segment.endedAt > range.start && segment.startedAt < range.end {
                let a = max(cursor, segment.startedAt), b = min(range.end, segment.endedAt)
                guard b > a else { continue }
                totals[segment.resolution.categoryID, default: 0] += b.timeIntervalSince(a)
                cursor = b
            }
        }
        let total = ranges.reduce(0) { $0 + $1.end.timeIntervalSince($1.start) }
        let entries = totals.map { Entry(categoryID: $0.key, duration: $0.value) }.sorted {
            if $0.duration == $1.duration { return $0.categoryID < $1.categoryID }
            return $0.duration > $1.duration
        }
        return Self(entries: entries, undetected: max(0, total - totals.values.reduce(0, +)), total: total)
    }
}
