import Foundation

/// Recurring wall-clock hours in the Mac's current time zone. Weekdays use
/// Calendar's stable numbering (Sunday = 1), independent of display order.
struct ActiveHoursSchedule: Codable, Equatable, Sendable {
    var isEnabled = false
    var weekdays: Set<Int> = [2, 3, 4, 5, 6]
    var startMinute = 9 * 60
    var endMinute = 17 * 60
    var pausesTracking = false

    var isValid: Bool {
        !weekdays.isEmpty && weekdays.isSubset(of: Set(1...7))
            && (0..<1440).contains(startMinute) && (0..<1440).contains(endMinute)
    }

    var isZeroDuration: Bool { startMinute == endMinute }

    var spansMidnight: Bool { !isZeroDuration && endMinute < startMinute }

    private enum CodingKeys: String, CodingKey {
        case isEnabled, weekdays, startMinute, endMinute, pausesTracking
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(weekdays.sorted(), forKey: .weekdays)
        try container.encode(startMinute, forKey: .startMinute)
        try container.encode(endMinute, forKey: .endMinute)
        try container.encode(pausesTracking, forKey: .pausesTracking)
    }

    /// Half-open intervals: start is included, end is excluded. An overnight
    /// interval belongs to its starting weekday, including its next-day tail.
    func state(at now: Date, calendar: Calendar = .autoupdatingCurrent) -> ActiveHoursState? {
        guard isEnabled else { return nil }
        guard !isZeroDuration else {
            return ActiveHoursState(window: nil, nextTransition: nil)
        }
        let schedule = isValid ? self : ActiveHoursSchedule()
        let today = calendar.startOfDay(for: now)
        var intervals: [DateInterval] = []
        for offset in -1...8 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  schedule.weekdays.contains(calendar.component(.weekday, from: day)),
                  let endDay = calendar.date(byAdding: .day, value: schedule.spansMidnight ? 1 : 0, to: day),
                  let start = Self.time(schedule.startMinute, on: day, calendar: calendar),
                  let end = Self.time(schedule.endMinute, on: endDay, calendar: calendar), end > start else { continue }
            intervals.append(DateInterval(start: start, end: end))
        }
        if let interval = intervals.first(where: { $0.start <= now && now < $0.end }) {
            return ActiveHoursState(window: interval, nextTransition: interval.end)
        }
        return ActiveHoursState(window: nil, nextTransition: intervals.map(\.start).filter { $0 > now }.min())
    }

    private static func time(_ minute: Int, on day: Date, calendar: Calendar) -> Date? {
        // Spring-forward gaps use the next valid wall time; a repeated fall-back
        // hour uses its first occurrence. Calendar arithmetic preserves local days.
        calendar.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: day,
                      matchingPolicy: .nextTime, repeatedTimePolicy: .first, direction: .forward)
    }
}

struct ActiveHoursState: Codable, Equatable, Sendable {
    let window: DateInterval?
    let nextTransition: Date?
    var isOutside: Bool { window == nil }
}
