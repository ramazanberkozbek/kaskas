import Charts
import SwiftUI

struct DashboardTodayChart: View {
    let data: DashboardTodayChartData
    private var date: Date { data.date }

    @State private var hoveredHour: Int?

    private var currentLabel: LocalizedStringKey {
        Calendar.current.isDateInToday(date) ? "dashboard.today" : "dashboard.day.selected"
    }
    private var previousLabel: LocalizedStringKey {
        Calendar.current.isDateInToday(date) ? "dashboard.yesterday" : "dashboard.day.previous"
    }

    var body: some View {
        let current = data.todayHours
        let previous = data.yesterdayHours
        Chart {
            ForEach(0..<24, id: \.self) { hour in
                LineMark(
                    x: .value("Hour", Double(hour) + 0.5),
                    y: .value("Hours", current[hour]),
                    series: .value("Day", "today")
                )
                .foregroundStyle(StatisticsStyle.studying)
                if current[hour] > 0 {
                    PointMark(
                        x: .value("Hour", Double(hour) + 0.5),
                        y: .value("Hours", current[hour])
                    )
                    .foregroundStyle(StatisticsStyle.studying)
                }
                LineMark(
                    x: .value("Hour", Double(hour) + 0.5),
                    y: .value("Hours", previous[hour]),
                    series: .value("Day", "yesterday")
                )
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                .foregroundStyle(StatisticsStyle.average)
            }
        }
        .chartLegend(.hidden)
        .chartXScale(domain: 0.0...24.0)
        .chartYScale(domain: 0.0...1.0)
        .chartXAxis {
            AxisMarks(values: [0.0, 6, 12, 18, 24]) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let hour = value.as(Double.self) {
                        Text(String(format: "%02d:00", Int(hour)))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: [0.0, 0.25, 0.5, 0.75, 1.0]) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let hours = value.as(Double.self) {
                        Text(StatisticsDuration.label(hours * 3600))
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
                        Path { path in
                            path.move(to: CGPoint(x: x, y: plot.minY))
                            path.addLine(to: CGPoint(x: x, y: plot.maxY))
                        }
                        .stroke(.primary.opacity(0.55), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .allowsHitTesting(false)
                        VStack(alignment: .leading, spacing: 7) {
                            Text(String(format: "%02d:00–%02d:00", hoveredHour, hoveredHour + 1))
                                .font(.subheadline.weight(.semibold))
                            Divider()
                            tooltipRow(currentLabel, value: StatisticsDuration.label(current[hoveredHour] * 3600), color: StatisticsStyle.studying)
                            tooltipRow(previousLabel, value: StatisticsDuration.label(previous[hoveredHour] * 3600), color: StatisticsStyle.average)
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
        .onChange(of: date) { _, _ in hoveredHour = nil }
    }

    private func tooltipOriginX(for x: CGFloat, in plot: CGRect) -> CGFloat {
        let width: CGFloat = 230
        let spacing: CGFloat = 14
        let preferred = x + spacing + width <= plot.maxX ? x + spacing : x - spacing - width
        return min(max(plot.minX, preferred), max(plot.minX, plot.maxX - width))
    }

    private func tooltipRow(_ label: LocalizedStringKey, value: String, color: Color) -> some View {
        HStack(spacing: 7) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label)
            Spacer(minLength: 8)
            Text(value).fontWeight(.semibold).monospacedDigit()
        }
    }
}
