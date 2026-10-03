import Combine
import SwiftUI

struct StatisticsView: View {
    let controller: SessionController

    @State private var period: StatisticsPeriod = .seven
    @State private var endDate = Calendar.current.startOfDay(for: Date())
    @State private var now = Date()
    @State private var intervals: [ActivityInterval] = []
    @State private var categorySummary: CategoryUsageSummary = .empty
    @State private var chartSnapshot: StatisticsChartSnapshot = .empty
    @State private var loaded = false
    @State private var loadedStart: Date?
    @State private var loadedEnd: Date?
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale

    private let refreshClock = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: SettingsPageLayout.sectionSpacing, pinnedViews: [.sectionHeaders]) {
                SettingsPaneHeader(title: "settings.sidebar.statistics")

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("stats.summary.title")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.primary)

                            Text("stats.summary.subtitle")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }

                        StatisticsSummaryCards(days: chartSnapshot.distributionDays)
                    }

                    StatisticsChartSection(
                        title: "stats.trend.title",
                        subtitle: "stats.trend.subtitle",
                        legend: [
                            (StatisticsStyle.studying, "stats.kind.studying"),
                            (StatisticsStyle.average, "stats.trend.average")
                        ]
                    ) {
                        StudyTrendChart(data: chartSnapshot.trend)
                    }

                    CategoryUsageView(
                        summary: categorySummary,
                        registry: controller.categoryRegistry,
                        storageFailed: controller.appUsage.storageFailed,
                        showsAppSegments: true
                    )

                    UsageDonutCharts(summary: categorySummary, registry: controller.categoryRegistry)

                    StatisticsChartSection(
                        title: "stats.distribution.title",
                        subtitle: "stats.distribution.subtitle",
                        legend: ActivityKind.allCases.map { ($0.color, $0.labelKey) }
                    ) {
                        StatisticsDistributionChart(
                            days: chartSnapshot.distributionDays,
                            points: chartSnapshot.distributionPoints,
                            period: period
                        )
                    }

                    StatisticsChartSection(
                        title: "stats.hourly.title",
                        subtitle: period == .thirty ? "stats.hourly.averageSubtitle" : "stats.hourly.subtitle",
                        legend: hourlyLegend
                    ) {
                        StatisticsHourlyChart(
                            days: chartSnapshot.hourlyDays,
                            points: hourlyPoints,
                            period: period
                        )
                    }

                    YearActivityHeatmap(
                        selectedYear: selectedYear,
                        data: chartSnapshot.year,
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
                } header: {
                    dateFilterBar
                }
            }
            .settingsPageContent()
        }
        .scrollIndicators(.hidden)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { reload(force: true) }
        .onChange(of: period) { _, _ in resetSelectionAndReload() }
        .onChange(of: endDate) { _, _ in resetSelectionAndReload() }
        .onReceive(refreshClock) { date in
            let previousToday = Calendar.current.startOfDay(for: now)
            now = date
            let today = Calendar.current.startOfDay(for: date)
            if endDate == previousToday { endDate = today }
            reload(force: true)
        }
    }

    private var dateFilterBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            StatisticsRangeControls(period: $period, endDate: $endDate, now: now)
            Text("stats.range.scope")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 12)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .bottom) { Divider() }
    }

    private var selectedYear: Int { Calendar.current.component(.year, from: endDate) }
    private var hourlyPeriod: HourlyPeriod { period == .seven ? .week : .day }
    private var hourlyValueLabel: String { period == .thirty ? "stats.hourly.average" : "stats.kind.studying" }

    private var selectedWindow: (start: Date, end: Date) {
        period.window(endingAt: endDate)
    }

    private var hourlyPoints: [StatisticsChartSnapshot.HourlyPoint] {
        period == .thirty ? chartSnapshot.averageHourlyPoints : chartSnapshot.hourlyPoints
    }

    private var hourlyLegend: [(Color, String)] {
        if hourlyPeriod == .day {
            return [(StatisticsStyle.computerInactive, hourlyValueLabel)]
        }
        let palette: [Color] = [
            StatisticsStyle.computerInactive,
            StatisticsStyle.studying,
            StatisticsStyle.breakTime,
            StatisticsStyle.average,
            .pink, .mint, .orange
        ]
        return chartSnapshot.hourlyDays.enumerated().map { index, day in
            (palette[index % palette.count], day.date.formatted(.dateTime.weekday(.abbreviated).day().locale(locale)))
        }
    }

    private func resetSelectionAndReload() {
        reload()
    }

    private func reload(force: Bool = false) {
        let trace = PerformanceTrace.begin("Statistics reload")
        defer { PerformanceTrace.end(trace) }
        let calendar = Calendar.current
        let trendStart = calendar.date(byAdding: .day, value: -6, to: selectedWindow.start) ?? selectedWindow.start
        let yearStart = calendar.date(from: DateComponents(year: selectedYear, month: 1, day: 1)) ?? now
        let start = min(trendStart, yearStart)
        let end = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        let categoryEnd = calendar.date(byAdding: .day, value: 1, to: selectedWindow.end) ?? now
        let coversWindow = loadedStart.map { start >= $0 } == true && loadedEnd.map { end <= $0 } == true
        if force || !coversWindow {
            intervals = controller.activityIntervals(from: start, to: end, now: now)
            loadedStart = start
            loadedEnd = end
            loaded = true
        }
        let appUsage = controller.appUsage.segments(from: selectedWindow.start, to: categoryEnd, now: now)
        categorySummary = .make(intervals: intervals, usage: appUsage, from: selectedWindow.start, to: categoryEnd)
        chartSnapshot = .make(intervals: intervals, trendWindow: selectedWindow,
                              distributionWindow: selectedWindow, hourlyWindow: selectedWindow, year: selectedYear)
    }
}
