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
                            monthLabels(for: weeks)
                            HStack(alignment: .top, spacing: cellSpacing) {
                                ForEach(weeks.indices, id: \.self) { index in
                                    VStack(spacing: cellSpacing) {
                                        ForEach(weeks[index], id: \.self) { date in
                                            dayCell(for: date, activityByDate: activityByDate)
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

    private func monthLabels(for weeks: [[Date]]) -> some View {
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

    private func dayCell(for date: Date, activityByDate: [Date: TimeInterval]) -> some View {
        let calendar = Calendar.current
        let isInYear = calendar.component(.year, from: date) == selectedYear
        let duration = activityByDate[calendar.startOfDay(for: date)] ?? 0
        let level = intensity(for: duration)
        let minutes = Int((duration / 60).rounded())
        let focusText = focusDurationText(for: minutes)
        return RoundedRectangle(cornerRadius: 2)
            .fill(isInYear ? color(for: level) : .clear)
            .frame(width: cellSize, height: cellSize)
            .contentShape(Rectangle())
            .overlay {
                if calendar.isDateInToday(date) {
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(StatisticsStyle.kaskasPaused, lineWidth: 1)
                }
                if isInYear && minutes > 0 && hoveredDate == date {
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(.primary, lineWidth: 1.5)
                }
            }
            .onHover { isHovered in
                guard isInYear && minutes > 0 else { return }
                if isHovered {
                    hoveredDate = date
                } else if hoveredDate == date {
                    hoveredDate = nil
                }
            }
            .popover(isPresented: Binding(
                get: { isInYear && minutes > 0 && hoveredDate == date },
                set: { if !$0 && hoveredDate == date { hoveredDate = nil } }
            ), arrowEdge: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(date.formatted(.dateTime.month(.abbreviated).day().locale(locale)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(focusText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(StatisticsStyle.studying)
                }
                .padding(10)
            }
            .accessibilityLabel(date.formatted(.dateTime.month(.wide).day().year().locale(locale)))
            .accessibilityValue(focusText)
    }

    private func focusDurationText(for totalMinutes: Int) -> String {
        let hours = totalMinutes / 60
        let remainingMinutes = totalMinutes % 60
        if hours > 0 && remainingMinutes > 0 {
            return String(format: String(localized: "stats.year.focusHoursAndMinutes"), hours, remainingMinutes)
        } else if hours > 0 {
            return String(format: String(localized: "stats.year.focusHours"), hours)
        } else {
            return String(format: String(localized: "stats.year.focusMinutes"), totalMinutes)
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
