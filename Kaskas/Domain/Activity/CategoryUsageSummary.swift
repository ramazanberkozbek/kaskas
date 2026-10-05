import Foundation

nonisolated struct CategoryUsageSummary: Equatable, Sendable {
    struct AppEntry: Equatable, Identifiable, Sendable {
        let app: ForegroundApp
        let duration: TimeInterval

        var id: String {
            let bundleID = CategoryResolver.normalize(app.bundleID ?? "")
            return bundleID.isEmpty
                ? "name:\(CategoryResolver.normalize(app.name))"
                : "bundle:\(bundleID)"
        }
    }

    struct Entry: Equatable, Identifiable, Sendable {
        let categoryID: String
        let duration: TimeInterval
        let resolvedDuration: TimeInterval
        let apps: [AppEntry]
        var id: String { categoryID }
    }

    let entries: [Entry]
    let undetected: TimeInterval
    let undetectedApps: [AppEntry]
    let unrecordedDuration: TimeInterval
    let total: TimeInterval

    static let empty = Self(entries: [], undetected: 0, undetectedApps: [], unrecordedDuration: 0, total: 0)

    var resolvedDuration: TimeInterval { entries.reduce(0) { $0 + $1.resolvedDuration } }

    /// Combines an app's historical category assignments and unresolved visits.
    var apps: [AppEntry] {
        var totals: [String: AppEntry] = [:]
        for entry in entries.flatMap(\.apps) + undetectedApps {
            Self.addApp(entry.app, duration: entry.duration, to: &totals)
        }
        return Self.sortedApps(totals)
    }

    /// Clips to the authoritative study timeline, including retrospective idle edits.
    /// Overlapping/replayed usage is counted once, with a deterministic first-record winner.
    static func make(intervals: [ActivityInterval], usage: [AppUsageSegment], from start: Date, to end: Date) -> Self {
        guard end > start else { return .empty }
        let relevantUsage = usage.filter { $0.startedAt < end && $0.endedAt > start }
        return Timeline(usage: relevantUsage).summary(intervals: intervals, from: start, to: end)
    }

    /// Reusable, nonoverlapping usage timeline. Sorting and resolving replayed/overlapping
    /// records happens once; multiple session/window summaries can share the result.
    struct Timeline: Sendable {
        let segments: [AppUsageSegment]

        private init(segments: [AppUsageSegment]) {
            self.segments = segments
        }

        /// Filtering winner slices preserves their order and nonoverlap.
        func filter(_ isIncluded: (AppUsageSegment) -> Bool) -> Self {
            Self(segments: segments.filter(isIncluded))
        }

        init(usage: [AppUsageSegment]) {
            let ordered = usage.sorted {
                if $0.startedAt == $1.startedAt { return $0.id.uuidString < $1.id.uuidString }
                return $0.startedAt < $1.startedAt
            }
            var winners: [AppUsageSegment] = []
            var coveredUntil: Date?
            for segment in ordered {
                let start = max(segment.startedAt, coveredUntil ?? segment.startedAt)
                guard segment.endedAt > start else { continue }
                winners.append(.init(id: segment.id, app: segment.app, resolution: segment.resolution,
                                     startedAt: start, endedAt: segment.endedAt))
                coveredUntil = segment.endedAt
            }
            segments = winners
        }

        /// After sorting study intervals, intersection costs O(log S + R + K): merged study
        /// ranges plus usage slices in the requested window. A spanning slice is
        /// revisited at most once per study range, without rescanning other slices.
        func summary(intervals: [ActivityInterval], from start: Date, to end: Date) -> CategoryUsageSummary {
            guard end > start else { return .empty }
            var ranges: [(start: Date, end: Date)] = []
            for interval in intervals.filter({ $0.kind == .studying && $0.startedAt < end && $0.endedAt > start })
                .sorted(by: { $0.startedAt < $1.startedAt }) {
                let a = max(start, interval.startedAt), b = min(end, interval.endedAt)
                guard b > a else { continue }
                if let last = ranges.indices.last, a <= ranges[last].end { ranges[last].end = max(ranges[last].end, b) }
                else { ranges.append((a, b)) }
            }
            // Winner slices are disjoint, so their ends are ordered too.
            var segmentIndex = firstSegment(endingAfter: start)
            var totals: [String: TimeInterval] = [:]
            var resolvedTotals: [String: TimeInterval] = [:]
            var appTotals: [String: [String: AppEntry]] = [:]
            var undetectedAppTotals: [String: AppEntry] = [:]
            for range in ranges {
                while segmentIndex < segments.count && segments[segmentIndex].endedAt <= range.start {
                    segmentIndex += 1
                }
                while segmentIndex < segments.count {
                    let segment = segments[segmentIndex]
                    guard segment.startedAt < range.end else { break }
                    let a = max(range.start, segment.startedAt), b = min(range.end, segment.endedAt)
                    let duration = b.timeIntervalSince(a)
                    let categoryID = segment.resolution.categoryID
                    if segment.resolution.isResolved {
                        totals[categoryID, default: 0] += duration
                        resolvedTotals[categoryID, default: 0] += duration
                        CategoryUsageSummary.addApp(segment.app, duration: duration, to: &appTotals[categoryID, default: [:]])
                    } else {
                        CategoryUsageSummary.addApp(segment.app, duration: duration, to: &undetectedAppTotals)
                    }
                    if segment.endedAt > range.end { break }
                    segmentIndex += 1
                }
            }
            let total = ranges.reduce(0) { $0 + $1.end.timeIntervalSince($1.start) }
            let entries = totals.map {
                let apps = CategoryUsageSummary.sortedApps(appTotals[$0.key, default: [:]])
                return Entry(categoryID: $0.key, duration: $0.value,
                             resolvedDuration: resolvedTotals[$0.key, default: 0], apps: apps)
            }.sorted {
                if $0.duration == $1.duration { return $0.categoryID < $1.categoryID }
                return $0.duration > $1.duration
            }
            let undetected = max(0, total - totals.values.reduce(0, +))
            let undetectedApps = CategoryUsageSummary.sortedApps(undetectedAppTotals)
            let unrecordedDuration = max(0, undetected - undetectedApps.reduce(0) { $0 + $1.duration })
            return CategoryUsageSummary(entries: entries, undetected: undetected, undetectedApps: undetectedApps,
                        unrecordedDuration: unrecordedDuration, total: total)
        }

        private func firstSegment(endingAfter date: Date) -> Int {
            var lower = 0, upper = segments.count
            while lower < upper {
                let middle = lower + (upper - lower) / 2
                if segments[middle].endedAt <= date { lower = middle + 1 }
                else { upper = middle }
            }
            return lower
        }
    }

    private static func addApp(_ app: ForegroundApp, duration: TimeInterval, to totals: inout [String: AppEntry]) {
        let entry = AppEntry(app: app, duration: duration)
        let id = entry.id
        let previous = totals[id]
        totals[id] = AppEntry(app: previous?.app ?? app, duration: (previous?.duration ?? 0) + duration)
    }

    private static func sortedApps(_ totals: [String: AppEntry]) -> [AppEntry] {
        totals.values.sorted {
            if $0.duration == $1.duration { return $0.id < $1.id }
            return $0.duration > $1.duration
        }
    }
}
