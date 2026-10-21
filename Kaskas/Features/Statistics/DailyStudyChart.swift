import Charts
import SwiftUI

struct DailyStudyChart: View {
    let data: DailyStudyChartData
    let now: Date
    @State private var hoveredHour: Int?
    @Environment(\.locale) private var locale

    var body: some View {
        let current = data.todayHours
        let previous = data.yesterdayHours
        let visibleHours = data.visibleHours(at: now)
        let scale = DurationChartScale(maximum: max(current.max() ?? 0, previous.max() ?? 0),
                                       minimum: 1, secondsPerUnit: 3600)
        Chart {
            ForEach(0..<24, id: \.self) { hour in
                if visibleHours.contains(hour) {
                    LineMark(
                        x: .value("Hour", data.position(for: hour, at: now)),
                        y: .value("Hours", current[hour]),
                        series: .value("Day", "today")
                    )
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(StatisticsStyle.studying)

                    if visibleHours.count == 1 && current[hour] > 0 {
                        PointMark(
                            x: .value("Hour", data.position(for: hour, at: now)),
                            y: .value("Hours", current[hour])
                        )
                        .foregroundStyle(StatisticsStyle.studying)
                    }
                }
                LineMark(
                    x: .value("Hour", Double(hour) + 0.5),
                    y: .value("Hours", previous[hour]),
                    series: .value("Day", "yesterday")
                )
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round, dash: [5, 5]))
                .foregroundStyle(StatisticsStyle.average)
            }
        }
        .chartLegend(.hidden)
        .chartXScale(domain: 0.0...24.0)
        .chartYScale(domain: 0...scale.upperBound)
        .chartXAxis {
            AxisMarks(values: [0.0, 6, 12, 18, 24]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.primary.opacity(0.08))
                AxisTick(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.primary.opacity(0.12))
                AxisValueLabel {
                    if let hour = value.as(Double.self) {
                        Text(String(format: "%02d:00", Int(hour)))
                    }
                }
            }
        }
        .chartYAxis { DurationChartAxis.marks(scale: scale, locale: locale) }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .onContinuousHover { phase in
                            guard case .active(let location) = phase,
                                  let plotFrame = proxy.plotFrame else {
                                hoveredHour = nil
                                return
                            }
                            let plot = geometry[plotFrame]
                            guard plot.contains(location),
                                  let hour = proxy.value(atX: location.x - plot.minX, as: Double.self) else {
                                hoveredHour = nil
                                return
                            }
                            hoveredHour = min(23, max(0, Int(hour.rounded(.down))))
                        }
                    if let hoveredHour, let plotFrame = proxy.plotFrame,
                       let position = proxy.position(forX: Double(hoveredHour) + 0.5) {
                        let plot = geometry[plotFrame]
                        let x = plot.minX + position
                        ChartHoverGuide(x: x, plot: plot)
                        VStack(alignment: .leading, spacing: 7) {
                            Text(String(format: "%02d:00–%02d:00", hoveredHour, hoveredHour + 1))
                                .font(.subheadline.weight(.semibold))
                            Divider()
                            if visibleHours.contains(hoveredHour) {
                                ChartTooltipRow(data.currentLabelKey(at: now), value: StatisticsDuration.label(current[hoveredHour] * 3600, locale: locale), color: StatisticsStyle.studying)
                            }
                            ChartTooltipRow(data.previousLabelKey(at: now), value: StatisticsDuration.label(previous[hoveredHour] * 3600, locale: locale), color: StatisticsStyle.average)
                        }
                        .chartTooltip(width: 230)
                        .offset(x: ChartTooltipPosition.originX(for: x, in: plot), y: plot.minY + 8)
                        .allowsHitTesting(false)
                    }
                }
            }
        }
        .frame(height: 220)
        .onChange(of: data.date) { _, _ in hoveredHour = nil }
    }
}
