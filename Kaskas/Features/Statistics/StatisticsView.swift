import Combine
import SwiftUI

struct StatisticsView: View {
    let controller: SessionController

    @State private var period: StatisticsPeriod = .seven
    @State private var endDate = Calendar.current.startOfDay(for: Date())
    @State private var now = Date()
    @State private var categorySummary: CategoryUsageSummary = .empty
    @State private var chartSnapshot: StatisticsChartSnapshot = .empty
    @State private var loaded = false
    @State private var refreshTask: Task<Void, Never>?
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
                        subtitle: trendSubtitle,
                        legend: trendLegend
                    ) {
                        if period == .day {
                            DailyStudyChart(data: chartSnapshot.dailyTrend, now: now)
                        } else {
                            StudyTrendChart(data: chartSnapshot.trend)
                        }
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
                        subtitle: period == .year ? "stats.distribution.monthlySubtitle" : "stats.distribution.subtitle",
                        legend: ActivityKind.allCases.map { ($0.color, $0.labelKey) }
                    ) {
                        StatisticsDistributionChart(
                            buckets: chartSnapshot.distributionBuckets,
                            points: chartSnapshot.distributionPoints,
                            period: period
                        )
                    }

                    StatisticsChartSection(
                        title: "stats.hourly.title",
                        subtitle: period.usesHourlyAverage ? "stats.hourly.averageSubtitle" : "stats.hourly.subtitle",
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
                    } else if loaded && chartSnapshot.distributionDays.allSatisfy({ day in
                        ActivityKind.allCases.allSatisfy { day.duration(for: $0) == 0 }
                    }) {
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
        .onAppear { reload() }
        .onDisappear { refreshTask?.cancel() }
        .onChange(of: controller.historyRevision) { _, _ in reload() }
        .onChange(of: controller.categoryRegistry.revision) { _, _ in reload() }
        .onChange(of: controller.appUsage.exclusions.revision) { _, _ in reload() }
        .onChange(of: period) { _, _ in resetSelectionAndReload() }
        .onChange(of: endDate) { _, _ in resetSelectionAndReload() }
        .onReceive(refreshClock) { date in
            let previousToday = Calendar.current.startOfDay(for: now)
            now = date
            let today = Calendar.current.startOfDay(for: date)
            if endDate == previousToday { endDate = today }
            reload()
        }
    }

    private var dateFilterBar: some View {
        StatisticsRangeControls(period: $period, endDate: $endDate, now: now)
            .padding(.vertical, 12)
            .background(Color(nsColor: .windowBackgroundColor))
            .overlay(alignment: .bottom) { Divider() }
    }

    private var selectedYear: Int { Calendar.current.component(.year, from: endDate) }
    private var hourlyPeriod: HourlyPeriod { period == .seven ? .week : .day }
    private var hourlyValueLabel: String { period.usesHourlyAverage ? "stats.hourly.average" : "stats.kind.studying" }

    private var selectedWindow: (start: Date, end: Date) {
        let window = period.window(endingAt: endDate)
        return (window.start, min(window.end, Calendar.current.startOfDay(for: now)))
    }

    private var hourlyPoints: [StatisticsChartSnapshot.HourlyPoint] {
        period.usesHourlyAverage ? chartSnapshot.averageHourlyPoints : chartSnapshot.hourlyPoints
    }

    private var trendSubtitle: LocalizedStringKey {
        switch period {
        case .day: "stats.trend.dailySubtitle"
        case .year: "stats.trend.monthlySubtitle"
        case .seven, .thirty: "stats.trend.subtitle"
        }
    }

    private var trendLegend: [(Color, String)] {
        if period == .day {
            return [
                (StatisticsStyle.studying, chartSnapshot.dailyTrend.currentLabelKey(at: now)),
                (StatisticsStyle.average, chartSnapshot.dailyTrend.previousLabelKey(at: now))
            ]
        }
        if period == .year { return [(StatisticsStyle.studying, "stats.kind.studying")] }
        return [
            (StatisticsStyle.studying, "stats.kind.studying"),
            (StatisticsStyle.average, "stats.trend.average")
        ]
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

    private func reload() {
        refreshTask?.cancel()
        let calendar = Calendar.current
        let window = selectedWindow
        let year = selectedYear
        let refreshPeriod = period
        let refreshNow = now
        let categoryEnd = calendar.date(byAdding: .day, value: 1, to: window.end) ?? refreshNow
        let exclusions = controller.appUsage.exclusions.snapshot()
        let ranges = StatisticsHistoryRanges(window: window, year: year, now: refreshNow,
                                             calendar: calendar, exclusions: exclusions)
        refreshTask = Task {
            let trace = PerformanceTrace.begin("Statistics reload")
            defer { PerformanceTrace.end(trace) }
            let history = await controller.activityIntervalsAsync(from: ranges.activity.start, to: ranges.activity.end, now: refreshNow)
            guard !Task.isCancelled else { return }
            let usage = await controller.appUsage.segmentsAsync(from: ranges.usage.start, to: ranges.usage.end, now: refreshNow)
            guard !Task.isCancelled else { return }
            let excluded = await controller.appUsage.excludedIntervalsAsync(from: ranges.activity.start, to: ranges.activity.end, now: refreshNow)
            guard !Task.isCancelled else { return }
            guard let snapshot = try? await StatisticsRefreshSnapshot.make(intervals: history, usage: usage,
                window: window, categoryEnd: categoryEnd, year: year, calendar: calendar, period: refreshPeriod, excluded: excluded, exclusions: exclusions) else { return }
            guard !Task.isCancelled else { return }
            categorySummary = snapshot.categories
            chartSnapshot = snapshot.chart
            loaded = true
        }
    }
}
