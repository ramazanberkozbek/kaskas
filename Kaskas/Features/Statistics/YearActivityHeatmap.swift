import SwiftUI

struct YearActivityHeatmap: View {
    @Binding var selectedYear: Int
    let days: [DailyActivity]
    let scheme: ColorScheme

    private let cellSize: CGFloat = 8
    private let cellSpacing: CGFloat = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "square.grid.3x3.fill")
                    .foregroundStyle(StatisticsStyle.kaskasPaused)
                    .frame(width: 32, height: 32)
                    .background(
                        StatisticsStyle.kaskasPaused.opacity(0.15),
                        in: RoundedRectangle(cornerRadius: 9)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text("stats.year.title")
                        .font(.caption.weight(.bold))
                        .tracking(1.1)
                    Text("stats.year.subtitle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Spacer()
                    Button { selectedYear -= 1 } label: {
                        Image(systemName: "chevron.left")
                    }
                    .accessibilityLabel("stats.previousYear")
                    Text(selectedYear.formatted(.number.grouping(.never)))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                    Button { selectedYear += 1 } label: {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(selectedYear >= Calendar.current.component(.year, from: Date()))
                    .accessibilityLabel("stats.nextYear")
                }
                .buttonStyle(.plain)

                HStack(alignment: .bottom, spacing: 7) {
                    weekdayLabels
                    ScrollView(.horizontal, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 6) {
                            monthLabels
                            HStack(alignment: .top, spacing: cellSpacing) {
                                ForEach(weeks.indices, id: \.self) { index in
                                    VStack(spacing: cellSpacing) {
                                        ForEach(weeks[index], id: \.self) { date in
                                            dayCell(for: date)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Divider()
                HStack(spacing: 5) {
                    Spacer()
                    Text("stats.year.less")
                    ForEach(0..<5) { level in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color(for: level))
                            .frame(width: cellSize + 2, height: cellSize + 2)
                    }
                    Text("stats.year.more")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(StatisticsStyle.panelFill(for: scheme), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.09)))
        }
    }

    private var activityByDate: [Date: TimeInterval] {
        Dictionary(uniqueKeysWithValues: days.map { ($0.date, $0.studying) })
    }

    private var weeks: [[Date]] {
        let calendar = Calendar.current
        guard let yearStart = calendar.date(from: DateComponents(year: selectedYear, month: 1, day: 1)),
              let yearEnd = calendar.date(from: DateComponents(year: selectedYear, month: 12, day: 31)),
              let firstWeek = calendar.dateInterval(of: .weekOfYear, for: yearStart)?.start else {
            return []
        }
        var result: [[Date]] = []
        var weekStart = firstWeek
        while weekStart <= yearEnd {
            result.append((0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) })
            guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart),
                  next > weekStart else { break }
            weekStart = next
        }
        return result
    }

    private var monthLabels: some View {
        HStack(spacing: cellSpacing) {
            ForEach(weeks.indices, id: \.self) { index in
                let firstOfMonth = weeks[index].first {
                    Calendar.current.component(.year, from: $0) == selectedYear &&
                    Calendar.current.component(.day, from: $0) == 1
                }
                Color.clear
                    .frame(width: cellSize, height: 12)
                    .overlay(alignment: .leading) {
                        if let firstOfMonth {
                            Text(firstOfMonth.formatted(.dateTime.month(.abbreviated)).uppercased())
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }
            }
        }
        .frame(height: 12)
    }

    private var weekdayLabels: some View {
        let calendar = Calendar.current
        let labels = (0..<7).map { index in
            calendar.shortWeekdaySymbols[(calendar.firstWeekday - 1 + index) % 7]
        }
        return VStack(alignment: .trailing, spacing: cellSpacing) {
            ForEach(0..<7) { index in
                Text(index == 1 || index == 3 || index == 5 ? labels[index] : "")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: cellSize, alignment: .trailing)
            }
        }
    }

    private func dayCell(for date: Date) -> some View {
        let calendar = Calendar.current
        let isInYear = calendar.component(.year, from: date) == selectedYear
        let duration = activityByDate[calendar.startOfDay(for: date)] ?? 0
        let level = intensity(for: duration)
        return RoundedRectangle(cornerRadius: 2)
            .fill(isInYear ? color(for: level) : .clear)
            .frame(width: cellSize, height: cellSize)
            .overlay {
                if calendar.isDateInToday(date) {
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(StatisticsStyle.kaskasPaused, lineWidth: 1)
                }
            }
            .help(isInYear
                ? "\(date.formatted(date: .abbreviated, time: .omitted)) · \(StatisticsDuration.label(duration))"
                : "")
            .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
            .accessibilityValue(StatisticsDuration.label(duration))
    }

    private func intensity(for duration: TimeInterval) -> Int {
        switch duration {
        case ..<60: 0
        case ..<1800: 1
        case ..<5400: 2
        case ..<10800: 3
        default: 4
        }
    }

    private func color(for level: Int) -> Color {
        switch level {
        case 0: .primary.opacity(scheme == .dark ? 0.06 : 0.07)
        case 1: StatisticsStyle.studying.opacity(0.24)
        case 2: StatisticsStyle.studying.opacity(0.45)
        case 3: StatisticsStyle.studying.opacity(0.72)
        default: StatisticsStyle.studying
        }
    }
}
