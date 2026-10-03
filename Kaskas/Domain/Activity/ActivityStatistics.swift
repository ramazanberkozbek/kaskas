import Foundation

struct DailyActivity: Identifiable, Equatable {
    let date: Date
    var studying: TimeInterval = 0
    var breakTime: TimeInterval = 0
    var computerInactive: TimeInterval = 0
    var kaskasPaused: TimeInterval = 0
    var meeting: TimeInterval = 0

    var id: Date { date }

    func duration(for kind: ActivityKind) -> TimeInterval {
        switch kind {
        case .studying: studying
        case .breakTime: breakTime
        case .computerInactive: computerInactive
        case .kaskasPaused: kaskasPaused
        case .meeting: meeting
        }
    }

    mutating func add(_ duration: TimeInterval, to kind: ActivityKind) {
        switch kind {
        case .studying: studying += duration
        case .breakTime: breakTime += duration
        case .computerInactive: computerInactive += duration
        case .kaskasPaused: kaskasPaused += duration
        case .meeting: meeting += duration
        }
    }
}

enum ActivityStatistics {
    static func focusRanges(
        on date: Date,
        intervals: [ActivityInterval],
        calendar: Calendar = .current
    ) -> [(start: Date, end: Date)] {
        guard let day = calendar.dateInterval(of: .day, for: date) else { return [] }
        return mergedRanges(of: .studying, from: day.start, to: day.end, intervals: intervals)
    }

    static func focusMinutesByHour(
        on date: Date,
        intervals: [ActivityInterval],
        calendar: Calendar = .current
    ) -> [Double] {
        var minutes = Array(repeating: 0.0, count: 24)
        for range in focusRanges(on: date, intervals: intervals, calendar: calendar) {
            var cursor = range.start
            let end = range.end
            while cursor < end {
                guard let hour = calendar.dateInterval(of: .hour, for: cursor) else { break }
                let sliceEnd = min(end, hour.end)
                minutes[calendar.component(.hour, from: cursor)] += sliceEnd.timeIntervalSince(cursor) / 60
                cursor = sliceEnd
            }
        }
        return minutes
    }

    static func days(
        from start: Date,
        through end: Date,
        intervals: [ActivityInterval],
        calendar: Calendar = .current
    ) -> [DailyActivity] {
        let first = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: end)
        guard first <= last else { return [] }

        var days: [DailyActivity] = []
        var indexByDay: [Date: Int] = [:]
        var day = first
        while day <= last {
            indexByDay[day] = days.count
            days.append(DailyActivity(date: day))
            guard let next = calendar.date(byAdding: .day, value: 1, to: day), next > day else { break }
            day = next
        }

        let exclusiveEnd = calendar.date(byAdding: .day, value: 1, to: last) ?? last
        for kind in ActivityKind.allCases {
            for range in mergedRanges(of: kind, from: first, to: exclusiveEnd, intervals: intervals) {
                var cursor = range.start
                while cursor < range.end {
                    guard let dayInterval = calendar.dateInterval(of: .day, for: cursor),
                          let index = indexByDay[dayInterval.start] else { break }
                    let sliceEnd = min(range.end, dayInterval.end)
                    days[index].add(sliceEnd.timeIntervalSince(cursor), to: kind)
                    cursor = sliceEnd
                }
            }
        }
        return days
    }

    private static func mergedRanges(
        of kind: ActivityKind,
        from start: Date,
        to end: Date,
        intervals: [ActivityInterval]
    ) -> [(start: Date, end: Date)] {
        let ranges = intervals
            .filter { $0.kind == kind && $0.endedAt > start && $0.startedAt < end }
            .map { (start: max(start, $0.startedAt), end: min(end, $0.endedAt)) }
            .sorted { $0.start < $1.start }
        var merged: [(start: Date, end: Date)] = []
        for range in ranges {
            if let last = merged.indices.last, range.start <= merged[last].end {
                merged[last].end = max(merged[last].end, range.end)
            } else {
                merged.append(range)
            }
        }
        return merged
    }
}
