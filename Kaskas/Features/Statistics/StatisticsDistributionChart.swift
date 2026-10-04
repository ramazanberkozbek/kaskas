import Charts
import SwiftUI

struct StatisticsDistributionChart: View {
    let buckets: [ActivityChartBucket]
    let points: [StatisticsChartSnapshot.DistributionPoint]
    let period: StatisticsPeriod

    @State private var hoveredDate: Date?
    @Environment(\.locale) private var locale

    private var resolution: ActivityChartResolution { period == .year ? .month : .day }

    var body: some View {
        let selected = buckets.first { $0.date == hoveredDate }
        let dayAxisLabel = localizedString(resolution == .month ? "stats.axis.month" : "stats.axis.day", locale: locale)
        let hoursAxisLabel = localizedString("stats.axis.hours", locale: locale)
        let scale = DurationChartScale(maximum: buckets.map { $0.total / 3600 }.max() ?? 0,
                                       minimum: resolution == .month ? 1 : 24, secondsPerUnit: 3600)
        return Chart {
            ForEach(points) { point in
                BarMark(
                    x: .value(dayAxisLabel, point.date, unit: resolution.component),
                    y: .value(hoursAxisLabel, point.hours)
                )
                .foregroundStyle(point.kind.color)
                .cornerRadius(3)
            }
        }
        .chartLegend(.hidden)
        .chartXScale(domain: resolution.domain(for: buckets.map(\.date)))
        .chartYScale(domain: 0...scale.upperBound)
        .chartYAxis { DurationChartAxis.marks(scale: scale, locale: locale) }
        .chartXAxis {
            AxisMarks(values: .stride(by: resolution.component, count: period == .thirty ? 5 : 1)) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let date = value.as(Date.self), let first = buckets.first?.date,
                       let last = buckets.last?.date,
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
                            hoveredDate = dateAtHover(phase: phase, proxy: proxy, geometry: geometry, dates: buckets.map(\.date))
                        }
                    if let selected, let plotFrame = proxy.plotFrame,
                       let position = proxy.position(forX: resolution.center(of: selected.date)) {
                        let plot = geometry[plotFrame]
                        let x = plot.minX + position
                        let total = selected.total
                        ChartHoverGuide(x: x, plot: plot)
                        if total > 0, let y = proxy.position(forY: total / 3600),
                           let interval = Calendar.current.dateInterval(of: resolution.component, for: selected.date),
                           let left = proxy.position(forX: interval.start),
                           let right = proxy.position(forX: interval.end) {
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(.white.opacity(0.8), lineWidth: 2)
                                .frame(
                                    width: max(1, right - left) * 0.64,
                                    height: max(1, plot.maxY - plot.minY - y)
                                )
                                .position(x: x, y: plot.minY + y + (plot.maxY - plot.minY - y) / 2)
                                .allowsHitTesting(false)
                        }
                        VStack(alignment: .leading, spacing: 7) {
                            Text(selected.date.formatted(resolution == .month
                                ? .dateTime.month(.wide).year().locale(locale)
                                : .dateTime.month(.abbreviated).day().locale(locale)))
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
        .onChange(of: period) { _, _ in hoveredDate = nil }
        .onChange(of: buckets.first?.date) { _, _ in hoveredDate = nil }
        .onChange(of: buckets.last?.date) { _, _ in hoveredDate = nil }
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
        return dates.first {
            Calendar.current.isDate($0, equalTo: date, toGranularity: resolution.component)
        }
    }
}
