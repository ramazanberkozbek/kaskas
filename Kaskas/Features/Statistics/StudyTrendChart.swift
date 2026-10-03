import Charts
import SwiftUI

struct StudyTrendChart: View {
    let data: StudyTrendData

    @State private var hoveredDate: Date?
    @Environment(\.locale) private var locale

    var body: some View {
        let chartPoints = data.points
        let selected = chartPoints.first { $0.date == hoveredDate }
        let dayAxisLabel = localizedString("stats.axis.day", locale: locale)
        let hoursAxisLabel = localizedString("stats.axis.hours", locale: locale)
        return Chart {
            ForEach(chartPoints) { point in
                LineMark(
                    x: .value(dayAxisLabel, point.date, unit: .day),
                    y: .value(hoursAxisLabel, point.hours),
                    series: .value("Series", "daily")
                )
                .foregroundStyle(StatisticsStyle.studying)
                PointMark(
                    x: .value(dayAxisLabel, point.date, unit: .day),
                    y: .value(hoursAxisLabel, point.hours)
                )
                .foregroundStyle(StatisticsStyle.studying)
                LineMark(
                    x: .value(dayAxisLabel, point.date, unit: .day),
                    y: .value(hoursAxisLabel, point.averageHours),
                    series: .value("Series", "average")
                )
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                .foregroundStyle(StatisticsStyle.average)
            }
        }
        .chartLegend(.hidden)
        .chartYAxis { AxisMarks(position: .trailing) }
        .chartXAxis { AxisMarks(values: .stride(by: .day, count: chartPoints.count <= 7 ? 1 : 5)) }
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
                            Text(selected.date.formatted(.dateTime.month(.abbreviated).day().locale(locale)))
                                .font(.subheadline.weight(.semibold))
                            Divider()
                            tooltipRow("stats.kind.studying", value: StatisticsDuration.label(selected.hours * 3600, locale: locale), color: StatisticsStyle.studying)
                            tooltipRow("stats.trend.average", value: StatisticsDuration.label(selected.averageHours * 3600, locale: locale), color: StatisticsStyle.average)
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
        .onChange(of: data.points.first?.date) { _, _ in hoveredDate = nil }
        .onChange(of: data.points.last?.date) { _, _ in hoveredDate = nil }
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
