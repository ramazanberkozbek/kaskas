import Charts
import SwiftUI

struct StudyTrendChart: View {
    let data: StudyTrendData

    @State private var hoveredDate: Date?
    @Environment(\.locale) private var locale

    private var resolution: ActivityChartResolution { data.resolution }

    var body: some View {
        let chartPoints = data.points
        let scale = DurationChartScale(
            maximum: chartPoints.map { max($0.hours, $0.averageHours) }.max() ?? 0,
            minimum: 1, secondsPerUnit: 3600
        )
        let selected = chartPoints.first { $0.date == hoveredDate }
        let dayAxisLabel = localizedString(resolution == .month ? "stats.axis.month" : "stats.axis.day", locale: locale)
        let hoursAxisLabel = localizedString("stats.axis.hours", locale: locale)
        return Chart {
            ForEach(chartPoints) { point in
                LineMark(
                    x: .value(dayAxisLabel, point.date, unit: resolution.component),
                    y: .value(hoursAxisLabel, point.hours),
                    series: .value("Series", "daily")
                )
                .foregroundStyle(StatisticsStyle.studying)
                PointMark(
                    x: .value(dayAxisLabel, point.date, unit: resolution.component),
                    y: .value(hoursAxisLabel, point.hours)
                )
                .foregroundStyle(StatisticsStyle.studying)
                if resolution == .day {
                    LineMark(
                        x: .value(dayAxisLabel, point.date, unit: .day),
                        y: .value(hoursAxisLabel, point.averageHours),
                        series: .value("Series", "average")
                    )
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    .foregroundStyle(StatisticsStyle.average)
                }
            }
        }
        .chartLegend(.hidden)
        .chartXScale(domain: resolution.domain(for: chartPoints.map(\.date)))
        .chartYScale(domain: 0...scale.upperBound)
        .chartYAxis { DurationChartAxis.marks(scale: scale, locale: locale) }
        .chartXAxis {
            AxisMarks(values: .stride(by: resolution.component, count: resolution == .month || chartPoints.count <= 7 ? 1 : 5)) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let date = value.as(Date.self), let first = chartPoints.first?.date,
                       let last = chartPoints.last?.date,
                       (resolution == .month
                        ? Calendar.current.isDate(date, equalTo: first, toGranularity: .year)
                        : date <= last) {
                        Text(date.formatted(resolution == .month
                            ? .dateTime.month(.abbreviated).locale(locale)
                            : .dateTime.day().locale(locale)))
                    }
                }
            }
        }
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
                            hoveredDate = chartPoints.first {
                                Calendar.current.isDate($0.date, equalTo: date, toGranularity: resolution.component)
                            }?.date
                        }
                    if let selected, let plotFrame = proxy.plotFrame,
                       let position = proxy.position(forX: resolution.center(of: selected.date)) {
                        let plot = geometry[plotFrame]
                        let x = plot.minX + position
                        ChartHoverGuide(x: x, plot: plot)
                        if let y = proxy.position(forY: selected.hours) {
                            Circle()
                                .fill(StatisticsStyle.studying)
                                .frame(width: 12, height: 12)
                                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                                .position(x: x, y: plot.minY + y)
                                .allowsHitTesting(false)
                        }
                        VStack(alignment: .leading, spacing: 7) {
                            Text(selected.date.formatted(resolution == .month
                                ? .dateTime.month(.wide).year().locale(locale)
                                : .dateTime.month(.abbreviated).day().locale(locale)))
                                .font(.subheadline.weight(.semibold))
                            Divider()
                            ChartTooltipRow("stats.kind.studying", value: StatisticsDuration.label(selected.hours * 3600, locale: locale), color: StatisticsStyle.studying)
                            if resolution == .day {
                                ChartTooltipRow("stats.trend.average", value: StatisticsDuration.label(selected.averageHours * 3600, locale: locale), color: StatisticsStyle.average)
                            }
                        }
                        .chartTooltip(width: 230)
                        .offset(x: ChartTooltipPosition.originX(for: x, in: plot), y: plot.minY + 8)
                        .allowsHitTesting(false)
                    }
                }
            }
        }
        .frame(height: 220)
        .onChange(of: resolution) { _, _ in hoveredDate = nil }
        .onChange(of: data.points.first?.date) { _, _ in hoveredDate = nil }
        .onChange(of: data.points.last?.date) { _, _ in hoveredDate = nil }
    }
}
