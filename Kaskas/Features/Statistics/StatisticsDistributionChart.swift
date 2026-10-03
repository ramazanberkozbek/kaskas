import Charts
import SwiftUI

struct StatisticsDistributionChart: View {
    let days: [DailyActivity]
    let points: [StatisticsChartSnapshot.DistributionPoint]
    let period: StatisticsPeriod

    @State private var hoveredDate: Date?
    @Environment(\.locale) private var locale

    var body: some View {
        let selected = days.first { $0.date == hoveredDate }
        let dayAxisLabel = localizedString("stats.axis.day", locale: locale)
        let hoursAxisLabel = localizedString("stats.axis.hours", locale: locale)
        return Chart {
            ForEach(points) { point in
                BarMark(
                    x: .value(dayAxisLabel, point.date, unit: .day),
                    y: .value(hoursAxisLabel, point.hours)
                )
                .foregroundStyle(point.kind.color)
                .cornerRadius(3)
            }
        }
        .chartLegend(.hidden)
        .chartYScale(domain: 0...24)
        .chartYAxis {
            AxisMarks(position: .trailing, values: [0, 6, 12, 18, 24])
        }
        .chartXAxis { AxisMarks(values: .stride(by: .day, count: period == .thirty ? 5 : 1)) }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .onContinuousHover { phase in
                            hoveredDate = dateAtHover(phase: phase, proxy: proxy, geometry: geometry, dates: days.map(\.date))
                        }
                    if let selected, let plotFrame = proxy.plotFrame,
                       let position = proxy.position(forX: chartDayCenter(selected.date)) {
                        let plot = geometry[plotFrame]
                        let x = plot.minX + position
                        let total = ActivityKind.allCases.reduce(0.0) { $0 + selected.duration(for: $1) }
                        ChartHoverGuide(x: x, plot: plot)
                        if total > 0, let y = proxy.position(forY: total / 3600) {
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(.white.opacity(0.8), lineWidth: 2)
                                .frame(
                                    width: plot.width / CGFloat(days.count) * 0.64,
                                    height: max(1, plot.maxY - plot.minY - y)
                                )
                                .position(x: x, y: plot.minY + y + (plot.maxY - plot.minY - y) / 2)
                                .allowsHitTesting(false)
                        }
                        VStack(alignment: .leading, spacing: 7) {
                            Text(selected.date.formatted(.dateTime.month(.abbreviated).day().locale(locale)))
                                .font(.subheadline.weight(.semibold))
                            ForEach(ActivityKind.allCases, id: \.self) { kind in
                                ChartTooltipRow(kind.labelKey, value: StatisticsDuration.label(selected.duration(for: kind), locale: locale), color: kind.color)
                            }
                        }
                        .chartTooltip(width: 250)
                        .offset(x: ChartTooltipPosition.originX(for: x, in: plot, width: 250), y: plot.minY + 8)
                        .allowsHitTesting(false)
                    }
                }
            }
        }
        .frame(height: 220)
        .onChange(of: days.first?.date) { _, _ in hoveredDate = nil }
        .onChange(of: days.last?.date) { _, _ in hoveredDate = nil }
    }

    private func dateAtHover(
        phase: HoverPhase,
        proxy: ChartProxy,
        geometry: GeometryProxy,
        dates: [Date]
    ) -> Date? {
        guard case .active(let location) = phase,
              let plotFrame = proxy.plotFrame else { return nil }
        let plot = geometry[plotFrame]
        guard plot.contains(location),
              let date = proxy.value(atX: location.x - plot.minX, as: Date.self) else { return nil }
        let day = Calendar.current.startOfDay(for: date)
        return dates.first { Calendar.current.isDate($0, inSameDayAs: day) }
    }

    private func chartDayCenter(_ date: Date) -> Date {
        guard let day = Calendar.current.dateInterval(of: .day, for: date) else { return date }
        return day.start.addingTimeInterval(day.duration / 2)
    }
}
