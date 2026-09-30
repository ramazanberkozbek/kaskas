import Charts
import SwiftUI

struct StudyTrendChart: View {
    let days: [DailyActivity]
    let intervals: [ActivityInterval]

    @State private var hoveredDate: Date?

    private struct Point: Identifiable {
        let date: Date
        let hours: Double
        let averageHours: Double
        var id: Date { date }
    }

    private var points: [Point] {
        guard let start = days.first?.date, let end = days.last?.date else { return [] }
        let calendar = Calendar.current
        let averageStart = calendar.date(byAdding: .day, value: -6, to: start) ?? start
        let all = ActivityStatistics.days(from: averageStart, through: end, intervals: intervals)
        let amounts = Dictionary(uniqueKeysWithValues: all.map { ($0.date, $0.studying) })
        return days.map { day in
            let total = (0..<7).reduce(0.0) { result, distance in
                let date = calendar.date(byAdding: .day, value: -distance, to: day.date) ?? day.date
                return result + (amounts[date] ?? 0)
            }
            return Point(date: day.date, hours: day.studying / 3600, averageHours: total / 7 / 3600)
        }
    }

    var body: some View {
        let chartPoints = points
        let selected = chartPoints.first { $0.date == hoveredDate }
        Chart {
            ForEach(chartPoints) { point in
                LineMark(
                    x: .value(String(localized: "stats.axis.day"), point.date, unit: .day),
                    y: .value(String(localized: "stats.axis.hours"), point.hours),
                    series: .value("Series", "daily")
                )
                .foregroundStyle(StatisticsStyle.studying)
                PointMark(
                    x: .value(String(localized: "stats.axis.day"), point.date, unit: .day),
                    y: .value(String(localized: "stats.axis.hours"), point.hours)
                )
                .foregroundStyle(StatisticsStyle.studying)
                LineMark(
                    x: .value(String(localized: "stats.axis.day"), point.date, unit: .day),
                    y: .value(String(localized: "stats.axis.hours"), point.averageHours),
                    series: .value("Series", "average")
                )
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                .foregroundStyle(StatisticsStyle.average)
            }
        }
        .chartLegend(.hidden)
        .chartYAxis { AxisMarks(position: .trailing) }
        .chartXAxis { AxisMarks(values: .stride(by: .day, count: days.count == 7 ? 1 : 5)) }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .onContinuousHover { phase in
                            guard case .active(let location) = phase,
                                  let plotFrame = proxy.plotFrame else { hoveredDate = nil; return }
                            let plot = geometry[plotFrame]
                            guard plot.contains(location),
                                  let date = proxy.value(atX: location.x - plot.minX, as: Date.self) else {
                                hoveredDate = nil
                                return
                            }
                            let day = Calendar.current.startOfDay(for: date)
                            hoveredDate = chartPoints.first { Calendar.current.isDate($0.date, inSameDayAs: day) }?.date
                        }
                    if let selected, let plotFrame = proxy.plotFrame,
                       let day = Calendar.current.dateInterval(of: .day, for: selected.date),
                       let position = proxy.position(forX: day.start.addingTimeInterval(day.duration / 2)) {
                        let plot = geometry[plotFrame]
                        let x = plot.minX + position
                        Path { path in
                            path.move(to: CGPoint(x: x, y: plot.minY))
                            path.addLine(to: CGPoint(x: x, y: plot.maxY))
                        }
                        .stroke(.primary.opacity(0.55), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .allowsHitTesting(false)
                        if let y = proxy.position(forY: selected.hours) {
                            Circle()
                                .fill(StatisticsStyle.studying)
                                .frame(width: 12, height: 12)
                                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                                .position(x: x, y: plot.minY + y)
                                .allowsHitTesting(false)
                        }
                        VStack(alignment: .leading, spacing: 7) {
                            Text(selected.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.subheadline.weight(.semibold))
                            Divider()
                            tooltipRow("stats.kind.studying", value: StatisticsDuration.label(selected.hours * 3600), color: StatisticsStyle.studying)
                            tooltipRow("stats.trend.average", value: StatisticsDuration.label(selected.averageHours * 3600), color: StatisticsStyle.average)
                        }
                        .font(.subheadline)
                        .padding(12)
                        .frame(width: 230, alignment: .leading)
                        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.primary.opacity(0.17)))
                        .shadow(color: .black.opacity(0.22), radius: 12, y: 5)
                        .offset(x: tooltipOriginX(for: x, in: plot), y: plot.minY + 8)
                        .allowsHitTesting(false)
                    }
                }
            }
        }
        .frame(height: 220)
        .onChange(of: days.first?.date) { _, _ in hoveredDate = nil }
        .onChange(of: days.last?.date) { _, _ in hoveredDate = nil }
    }

    private func tooltipOriginX(for x: CGFloat, in plot: CGRect) -> CGFloat {
        let width: CGFloat = 230
        let spacing: CGFloat = 14
        let preferred = x + spacing + width <= plot.maxX ? x + spacing : x - spacing - width
        return min(max(plot.minX, preferred), max(plot.minX, plot.maxX - width))
    }

    private func tooltipRow(_ label: String, value: String, color: Color) -> some View {
        HStack(spacing: 7) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(LocalizedStringKey(label))
            Spacer(minLength: 8)
            Text(value).fontWeight(.semibold).monospacedDigit()
        }
    }
}
