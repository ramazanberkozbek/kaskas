import SwiftUI

struct YearActivityHeatmap: View {
    let selectedYear: Int
    let data: YearHeatmapData
    let scheme: ColorScheme

    @State private var hoveredDate: Date?
    @Environment(\.locale) private var locale

    private let cellSize: CGFloat = 11
    private let cellSpacing: CGFloat = 3

    var body: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weeks = data.weeks
        let activityByDate = data.activityByDate
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("stats.year.title")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("stats.year.subtitle")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 16) {
                Text(selectedYear.formatted(.number.grouping(.never)))
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .trailing)

                HStack(alignment: .bottom, spacing: 7) {
                    weekdayLabels
                    ScrollView(.horizontal, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 6) {
                            monthLabels(for: weeks, calendar: calendar)
                            HStack(alignment: .top, spacing: cellSpacing) {
                                ForEach(weeks.indices, id: \.self) { index in
                                    VStack(spacing: cellSpacing) {
                                        ForEach(weeks[index], id: \.self) { date in
                                            let isInYear = calendar.component(.year, from: date) == selectedYear
                                            let duration = activityByDate[calendar.startOfDay(for: date)] ?? 0
                                            HeatmapDayCell(
                                                date: date,
                                                isInYear: isInYear,
                                                isToday: calendar.isDate(date, inSameDayAs: today),
                                                duration: duration,
                                                isHovered: hoveredDate == date,
                                                scheme: scheme,
                                                cellSize: cellSize,
                                                onHover: { isHovered in
                                                    if isHovered {
                                                        hoveredDate = date
                                                    } else if hoveredDate == date {
                                                        hoveredDate = nil
                                                    }
                                                }
                                            )
                                            .equatable()
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
                            .fill(Self.color(for: level, scheme: scheme))
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

    private func monthLabels(for weeks: [[Date]], calendar: Calendar) -> some View {
        HStack(spacing: cellSpacing) {
            ForEach(weeks.indices, id: \.self) { index in
                let firstOfMonth = weeks[index].first {
                    calendar.component(.year, from: $0) == selectedYear &&
                    calendar.component(.day, from: $0) == 1
                }
                Color.clear
                    .frame(width: cellSize, height: 12)
                    .overlay(alignment: .leading) {
                        if let firstOfMonth {
                            Text(firstOfMonth.formatted(.dateTime.month(.abbreviated).locale(locale)).uppercased())
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
        var calendar = Calendar.current
        calendar.locale = locale
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

    static func color(for level: Int, scheme: ColorScheme) -> Color {
        switch level {
        case 0: .primary.opacity(scheme == .dark ? 0.06 : 0.07)
        case 1: StatisticsStyle.studying.opacity(0.24)
        case 2: StatisticsStyle.studying.opacity(0.45)
        case 3: StatisticsStyle.studying.opacity(0.72)
        default: StatisticsStyle.studying
        }
    }
}

private struct HeatmapDayCell: View, Equatable {
    let date: Date
    let isInYear: Bool
    let isToday: Bool
    let duration: TimeInterval
    let isHovered: Bool
    let scheme: ColorScheme
    let cellSize: CGFloat
    let onHover: (Bool) -> Void
    @Environment(\.locale) private var locale

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.date == rhs.date &&
        lhs.isInYear == rhs.isInYear &&
        lhs.isToday == rhs.isToday &&
        lhs.duration == rhs.duration &&
        lhs.isHovered == rhs.isHovered &&
        lhs.scheme == rhs.scheme &&
        lhs.cellSize == rhs.cellSize
    }

    var body: some View {
        let level = intensity(for: duration)
        let minutes = Int((duration / 60).rounded())
        RoundedRectangle(cornerRadius: 2)
            .fill(isInYear ? YearActivityHeatmap.color(for: level, scheme: scheme) : .clear)
            .frame(width: cellSize, height: cellSize)
            .contentShape(Rectangle())
            .overlay {
                if isToday {
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(StatisticsStyle.kaskasPaused, lineWidth: 1)
                }
                if isInYear && minutes > 0 && isHovered {
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(.primary, lineWidth: 1.5)
                }
            }
            .onHover { hovered in
                guard isInYear && minutes > 0 else { return }
                onHover(hovered)
            }
            .popover(isPresented: Binding(
                get: { isInYear && minutes > 0 && isHovered },
                set: { if !$0 { onHover(false) } }
            ), arrowEdge: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(date.formatted(.dateTime.month(.abbreviated).day().locale(locale)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(focusDurationText(for: minutes))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(StatisticsStyle.studying)
                }
                .padding(10)
                .environment(\.locale, locale)
            }
            .accessibilityLabel(date.formatted(.dateTime.month(.wide).day().year().locale(locale)))
            .accessibilityValue(focusDurationText(for: minutes))
    }

    private func focusDurationText(for totalMinutes: Int) -> String {
        let hours = totalMinutes / 60
        let remainingMinutes = totalMinutes % 60
        if hours > 0 && remainingMinutes > 0 {
            return String(format: localizedString("stats.year.focusHoursAndMinutes", locale: locale), hours, remainingMinutes)
        } else if hours > 0 {
            return String(format: localizedString("stats.year.focusHours", locale: locale), hours)
        } else {
            return String(format: localizedString("stats.year.focusMinutes", locale: locale), totalMinutes)
        }
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
}
