import Foundation

struct DailyActivity: Identifiable, Equatable {
    let date: Date
    var studying: TimeInterval = 0
    var breakTime: TimeInterval = 0
    var computerInactive: TimeInterval = 0
    var kaskasPaused: TimeInterval = 0

    var id: Date { date }

    func duration(for kind: ActivityKind) -> TimeInterval {
        switch kind {
        case .studying: studying
        case .breakTime: breakTime
        case .computerInactive: computerInactive
        case .kaskasPaused: kaskasPaused
        }
    }

    mutating func add(_ duration: TimeInterval, to kind: ActivityKind) {
        switch kind {
        case .studying: studying += duration
        case .breakTime: breakTime += duration
        case .computerInactive: computerInactive += duration
        case .kaskasPaused: kaskasPaused += duration
        }
    }
}

enum ActivityStatistics {
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
        for interval in intervals where interval.endedAt > interval.startedAt {
            var cursor = max(interval.startedAt, first)
            let end = min(interval.endedAt, exclusiveEnd)
            while cursor < end {
                guard let dayInterval = calendar.dateInterval(of: .day, for: cursor),
                      let index = indexByDay[dayInterval.start] else { break }
                let sliceEnd = min(end, dayInterval.end)
                days[index].add(sliceEnd.timeIntervalSince(cursor), to: interval.kind)
                cursor = sliceEnd
            }
        }
        return days
    }
}
