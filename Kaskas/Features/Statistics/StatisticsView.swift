import Charts
import Combine
import SwiftUI

struct StatisticsView: View {
    let controller: SessionController

    @State private var trendPeriod: StatisticsPeriod = .seven
    @State private var trendOffset = 0
    @State private var distributionPeriod: StatisticsPeriod = .seven
    @State private var distributionOffset = 0
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var now = Date()
    @State private var intervals: [ActivityInterval] = []
    @State private var loaded = false
    @Environment(\.colorScheme) private var colorScheme

    private let refreshClock = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("stats.title")
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                    Text("stats.subtitle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                summaryCards

                chartSection(
                    title: "stats.trend.title",
                    subtitle: "stats.trend.subtitle",
                    symbol: "chart.xyaxis.line",
                    tint: StatisticsStyle.studying,
                    period: $trendPeriod,
                    offset: $trendOffset,
                    legend: [
                        (StatisticsStyle.studying, "stats.kind.studying"),
                        (StatisticsStyle.average, "stats.trend.average")
                    ]
                ) {
                    trendChart
                }

                chartSection(
                    title: "stats.distribution.title",
                    subtitle: "stats.distribution.subtitle",
                    symbol: "chart.bar.fill",
                    tint: StatisticsStyle.breakTime,
                    period: $distributionPeriod,
                    offset: $distributionOffset,
                    legend: ActivityKind.allCases.map { ($0.color, $0.labelKey) }
                ) {
                    distributionChart
                }

                YearActivityHeatmap(
                    selectedYear: $selectedYear,
                    days: yearDays,
                    scheme: colorScheme
                )

                if controller.activityStorageFailed {
                    Label("stats.storageWarning", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else if loaded && intervals.isEmpty {
                    Text("stats.empty")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear(perform: reload)
        .onChange(of: trendPeriod) { _, _ in trendOffset = 0; reload() }
        .onChange(of: trendOffset) { _, _ in reload() }
        .onChange(of: distributionPeriod) { _, _ in distributionOffset = 0; reload() }
        .onChange(of: distributionOffset) { _, _ in reload() }
        .onChange(of: selectedYear) { _, _ in reload() }
        .onReceive(refreshClock) { date in now = date; reload() }
    }

    private var today: DailyActivity {
        ActivityStatistics.days(from: now, through: now, intervals: intervals).first
            ?? DailyActivity(date: Calendar.current.startOfDay(for: now))
    }

    private var summaryCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(ActivityKind.allCases, id: \.self) { kind in
                HStack(spacing: 12) {
                    Image(systemName: kind.symbol)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(kind.color)
                        .frame(width: 38, height: 38)
                        .background(kind.color.opacity(0.13), in: RoundedRectangle(cornerRadius: 11))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(LocalizedStringKey(kind.labelKey))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(StatisticsDuration.label(today.duration(for: kind)))
                            .font(.system(size: 21, weight: .bold, design: .rounded))
                            .monospacedDigit()
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(StatisticsStyle.panelFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.primary.opacity(0.08)))
            }
        }
    }

    private var trendWindow: (start: Date, end: Date) {
        trendPeriod.window(offset: trendOffset, now: now)
    }

    private var distributionWindow: (start: Date, end: Date) {
        distributionPeriod.window(offset: distributionOffset, now: now)
    }

    private var trendDays: [DailyActivity] {
        ActivityStatistics.days(from: trendWindow.start, through: trendWindow.end, intervals: intervals)
    }

    private var distributionDays: [DailyActivity] {
        ActivityStatistics.days(from: distributionWindow.start, through: distributionWindow.end, intervals: intervals)
    }

    private var yearDays: [DailyActivity] {
        let calendar = Calendar.current
        guard let start = calendar.date(from: DateComponents(year: selectedYear, month: 1, day: 1)),
              let end = calendar.date(from: DateComponents(year: selectedYear, month: 12, day: 31)) else {
            return []
        }
        return ActivityStatistics.days(from: start, through: end, intervals: intervals)
    }

    private struct TrendPoint: Identifiable {
        let date: Date
        let hours: Double
        let averageHours: Double
        var id: Date { date }
    }

    private var trendPoints: [TrendPoint] {
        let calendar = Calendar.current
        let averageStart = calendar.date(byAdding: .day, value: -6, to: trendWindow.start) ?? trendWindow.start
        let all = ActivityStatistics.days(from: averageStart, through: trendWindow.end, intervals: intervals)
        let amounts = Dictionary(uniqueKeysWithValues: all.map { ($0.date, $0.studying) })
        return trendDays.map { day in
            let total = (0..<7).reduce(0.0) { result, distance in
                let date = calendar.date(byAdding: .day, value: -distance, to: day.date) ?? day.date
                return result + (amounts[date] ?? 0)
            }
            return TrendPoint(date: day.date, hours: day.studying / 3600, averageHours: total / 7 / 3600)
        }
    }

    private var trendChart: some View {
        Chart {
            ForEach(trendPoints) { point in
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
        .chartXAxis { AxisMarks(values: .stride(by: .day, count: trendPeriod == .seven ? 1 : 5)) }
        .frame(height: 190)
    }

    private struct DistributionPoint: Identifiable {
        let date: Date
        let kind: ActivityKind
        let hours: Double
        var id: String { "\(date.timeIntervalSinceReferenceDate)-\(kind.rawValue)" }
    }

    private var distributionPoints: [DistributionPoint] {
        distributionDays.flatMap { day in
            ActivityKind.allCases.map {
                DistributionPoint(date: day.date, kind: $0, hours: day.duration(for: $0) / 3600)
            }
        }
    }

    private var distributionChart: some View {
        Chart(distributionPoints) { point in
            BarMark(
                x: .value(String(localized: "stats.axis.day"), point.date, unit: .day),
                y: .value(String(localized: "stats.axis.hours"), point.hours)
            )
            .foregroundStyle(point.kind.color)
            .cornerRadius(3)
        }
        .chartLegend(.hidden)
        .chartYAxis { AxisMarks(position: .trailing) }
        .chartXAxis { AxisMarks(values: .stride(by: .day, count: distributionPeriod == .seven ? 1 : 5)) }
        .frame(height: 190)
    }

    private func chartSection<Content: View>(
        title: String,
        subtitle: String,
        symbol: String,
        tint: Color,
        period: Binding<StatisticsPeriod>,
        offset: Binding<Int>,
        legend: [(Color, String)],
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .foregroundStyle(tint)
                    .frame(width: 32, height: 32)
                    .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(title))
                        .font(.caption.weight(.bold))
                        .tracking(1.1)
                    Text(LocalizedStringKey(subtitle))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 14) {
                StatisticsRangeControls(period: period, offset: offset, now: now)
                content()
                Divider()
                HStack(spacing: 16) {
                    ForEach(legend.indices, id: \.self) { index in
                        HStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(legend[index].0)
                                .frame(width: 13, height: 5)
                            Text(LocalizedStringKey(legend[index].1))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(16)
            .background(StatisticsStyle.panelFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.09)))
        }
    }

    private func reload() {
        let calendar = Calendar.current
        let trendStart = calendar.date(byAdding: .day, value: -6, to: trendWindow.start) ?? trendWindow.start
        let yearStart = calendar.date(from: DateComponents(year: selectedYear, month: 1, day: 1)) ?? now
        let start = min(trendStart, distributionWindow.start, yearStart)
        let end = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        intervals = controller.activityIntervals(from: start, to: end, now: now)
        loaded = true
    }
}

private struct StatisticsRangeControls: View {
    @Binding var period: StatisticsPeriod
    @Binding var offset: Int
    let now: Date

    var body: some View {
        let window = period.window(offset: offset, now: now)
        HStack(spacing: 8) {
            Button { offset += 1 } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel("stats.previousPeriod")

            Text("\(window.start.formatted(.dateTime.day().month(.abbreviated)))–\(window.end.formatted(.dateTime.day().month(.abbreviated)))")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()

            Button { offset = max(0, offset - 1) } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(offset == 0)
            .accessibilityLabel("stats.nextPeriod")

            Spacer(minLength: 8)

            Picker("stats.period", selection: $period) {
                ForEach(StatisticsPeriod.allCases) { item in
                    Text(LocalizedStringKey(item.labelKey)).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 112)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }
}
