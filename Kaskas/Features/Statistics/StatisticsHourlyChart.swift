import Charts
import SwiftUI

struct StatisticsHourlyChart: View {
    let days: [DailyActivity]
    let points: [StatisticsChartSnapshot.HourlyPoint]
    let period: StatisticsPeriod

    @State private var hoveredHour: Int?
    @Environment(\.locale) private var locale

    private var hourlyPeriod: HourlyPeriod { period == .seven ? .week : .day }
    private var hourlyValueLabel: String { period == .thirty ? "stats.hourly.average" : "stats.kind.studying" }

    var body: some View {
        let selectedHour = hoveredHour
        let upperBound = max(60, (points.map(\.minutes).max() ?? 0).rounded(.up))
        return Chart {
            if hourlyPeriod == .day {
                ForEach(points) { point in
                    RectangleMark(
                        xStart: .value("Hour start", Double(point.hour) + 0.14),
                        xEnd: .value("Hour end", Double(point.hour) + 0.86),
                        yStart: .value("Zero minutes", 0.0),
                        yEnd: .value("Minutes", point.minutes)
                    )
                    .foregroundStyle(StatisticsStyle.computerInactive)
                    .cornerRadius(3)
                }
            } else {
                ForEach(points) { point in
                    LineMark(
                        x: .value("Hour", Double(point.hour) + 0.5),
                        y: .value("Minutes", point.minutes),
                        series: .value("Day", point.date)
                    )
                    .foregroundStyle(hourlyColor(for: point.date))
                    .lineStyle(StrokeStyle(lineWidth: 1.7))
                }
            }
        }
        .chartLegend(.hidden)
        .chartXScale(domain: 0.0...24.0)
        .chartYScale(domain: 0...upperBound)
        .chartXAxis {
            AxisMarks(values: [0.0, 3, 6, 9, 12, 15, 18, 21]) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let hour = value.as(Double.self) {
                        Text(String(format: "%02d", Int(hour)))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: [0, 15, 30, 45, 60]) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let minutes = value.as(Int.self) {
                        Text(StatisticsDuration.label(Double(minutes) * 60, locale: locale))
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let location):
                                guard let plotFrame = proxy.plotFrame else { hoveredHour = nil; return }
                                let plot = geometry[plotFrame]
                                guard plot.contains(location),
                                      let hour = proxy.value(atX: location.x - plot.minX, as: Double.self) else {
                                    hoveredHour = nil
                                    return
                                }
                                hoveredHour = min(23, max(0, Int(hour.rounded(.down))))
                            case .ended:
                                hoveredHour = nil
                            }
                        }
                    if let selectedHour, let plotFrame = proxy.plotFrame,
                       let position = proxy.position(forX: Double(selectedHour) + 0.5) {
                        let plot = geometry[plotFrame]
                        let x = plot.minX + position
                        let activePoints = points.filter { $0.hour == selectedHour && $0.minutes > 0 }
                        let totalMinutes = activePoints.reduce(0.0) { $0 + $1.minutes }
                        ChartHoverGuide(x: x, plot: plot)
                        if hourlyPeriod == .day, let point = activePoints.first,
                           let y = proxy.position(forY: point.minutes),
                           let left = proxy.position(forX: Double(selectedHour) + 0.14),
                           let right = proxy.position(forX: Double(selectedHour) + 0.86) {
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(.white.opacity(0.8), lineWidth: 2)
                                .frame(width: right - left, height: max(1, plot.height - y))
                                .position(x: x, y: plot.minY + y + (plot.height - y) / 2)
                                .allowsHitTesting(false)
                        } else if hourlyPeriod == .week {
                            ForEach(activePoints) { point in
                                if let y = proxy.position(forY: point.minutes) {
                                    Circle()
                                        .fill(hourlyColor(for: point.date))
                                        .frame(width: 10, height: 10)
                                        .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
                                        .position(x: x, y: plot.minY + y)
                                        .allowsHitTesting(false)
                                }
                            }
                        }
                        VStack(alignment: .leading, spacing: 7) {
                            Text(String(format: "%02d:00–%02d:00", selectedHour, selectedHour + 1))
                                .font(.subheadline.weight(.semibold))
                            if hourlyPeriod == .week {
                                ChartTooltipRow("stats.total", value: StatisticsDuration.label(totalMinutes * 60, locale: locale), color: StatisticsStyle.computerInactive)
                                Divider()
                            }
                            if activePoints.isEmpty {
                                Text("stats.hourly.noFocus")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(activePoints) { point in
                                    ChartTooltipRow(
                                        hourlyPeriod == .day ? hourlyValueLabel : point.date.formatted(.dateTime.weekday(.abbreviated).day().locale(locale)),
                                        value: StatisticsDuration.label(point.minutes * 60, locale: locale),
                                        color: hourlyColor(for: point.date),
                                        isLocalizedKey: hourlyPeriod == .day
                                    )
                                }
                            }
                        }
                        .chartTooltip()
                        .offset(x: ChartTooltipPosition.originX(for: x, in: plot), y: plot.minY + 8)
                        .allowsHitTesting(false)
                    }
                }
            }
        }
        .frame(height: 220)
        .onChange(of: points.first?.date) { _, _ in hoveredHour = nil }
        .onChange(of: points.last?.date) { _, _ in hoveredHour = nil }
    }

    private func hourlyColor(for date: Date) -> Color {
        guard hourlyPeriod == .week else { return StatisticsStyle.computerInactive }
        let palette: [Color] = [
            StatisticsStyle.computerInactive,
            StatisticsStyle.studying,
            StatisticsStyle.breakTime,
            StatisticsStyle.average,
            .pink, .mint, .orange
        ]
        let index = days.firstIndex { $0.date == date } ?? 0
        return palette[index % palette.count]
    }
}
