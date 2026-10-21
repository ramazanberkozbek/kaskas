import Combine
import SwiftUI

struct StatisticsView: View {
    let controller: SessionController

    @Bindable var state: StatisticsViewState
    @State private var refreshTask: Task<Void, Never>?
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale

    private let refreshClock = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var period: StatisticsPeriod { state.period }
    private var endDate: Date { state.endDate }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: SettingsPageLayout.sectionSpacing, pinnedViews: [.sectionHeaders]) {
                SettingsPaneHeader(title: "settings.sidebar.statistics")

                Section {
                    if let snapshot = state.snapshot {
                        let period = snapshot.period
                        let endDate = snapshot.endDate
                        let chartSnapshot = snapshot.chart
                        let categorySummary = snapshot.categories
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

                        if period == .day {
                            DailyTrendChartSection(data: chartSnapshot.dailyTrend, state: state)
                        } else {
                            PeriodTrendChartSection(data: chartSnapshot.trend, period: period)
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
                            .id(period)
                        }

                        StatisticsChartSection(
                            title: "stats.hourly.title",
                            subtitle: period.usesHourlyAverage ? "stats.hourly.averageSubtitle" : "stats.hourly.subtitle",
                            legend: hourlyLegend(for: period, in: chartSnapshot)
                        ) {
                            StatisticsHourlyChart(
                                days: chartSnapshot.hourlyDays,
                                points: hourlyPoints(for: period, in: chartSnapshot),
                                period: period
                            )
                            .id(period)
                        }

                        YearActivityHeatmap(
                            selectedYear: year(from: endDate),
                            data: chartSnapshot.year,
                            scheme: colorScheme
                        )

                        if controller.activityStorageFailed {
                            Label("stats.storageWarning", systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        } else if chartSnapshot.distributionDays.allSatisfy({ day in
                            ActivityKind.allCases.allSatisfy { day.duration(for: $0) == 0 }
                        }) {
                            Text("stats.empty")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 120)
                    }
                } header: {
                    dateFilterBar
                }
            }
            .settingsPageContent()
        }
        .scrollIndicators(.hidden)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            state.updateClock(to: Date())
            reload()
        }
        .onDisappear { refreshTask?.cancel() }
        .onChange(of: controller.historyRevision) { _, _ in reload() }
        .onChange(of: controller.categoryRegistry.revision) { _, _ in reload() }
        .onChange(of: controller.appUsage.exclusions.revision) { _, _ in reload() }
        .onChange(of: period) { _, _ in reload() }
        .onChange(of: endDate) { _, _ in reload() }
        .onReceive(refreshClock) { date in
            state.updateClock(to: date)
            if period == .day {
                reload()
            }
        }
    }

    private var dateFilterBar: some View {
        StatisticsRangeControls(period: $state.period, endDate: $state.endDate, today: state.today)
            .padding(.vertical, 12)
            .background(Color(nsColor: .windowBackgroundColor))
            .overlay(alignment: .bottom) { Divider() }
    }

    private func year(from date: Date) -> Int {
        Calendar.current.component(.year, from: date)
    }

    private var selectedWindow: (start: Date, end: Date) {
        let window = period.window(endingAt: endDate)
        return (window.start, min(window.end, state.today))
    }

    private func hourlyPoints(for period: StatisticsPeriod, in chart: StatisticsChartSnapshot) -> [StatisticsChartSnapshot.HourlyPoint] {
        period.usesHourlyAverage ? chart.averageHourlyPoints : chart.hourlyPoints
    }

    private func hourlyLegend(for period: StatisticsPeriod, in chart: StatisticsChartSnapshot) -> [(Color, String)] {
        if period != .seven {
            let label = period.usesHourlyAverage ? "stats.hourly.average" : "stats.kind.studying"
            return [(StatisticsStyle.computerInactive, label)]
        }
        let palette: [Color] = [
            StatisticsStyle.computerInactive,
            StatisticsStyle.studying,
            StatisticsStyle.breakTime,
            StatisticsStyle.average,
            .pink, .mint, .orange
        ]
        return chart.hourlyDays.enumerated().map { index, day in
            (palette[index % palette.count], day.date.formatted(.dateTime.weekday(.abbreviated).day().locale(locale)))
        }
    }

    private func reload() {
        refreshTask?.cancel()
        let calendar = Calendar.current
        let window = selectedWindow
        let year = year(from: endDate)
        let refreshPeriod = period
        let refreshNow = state.now
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
            state.snapshot = snapshot
        }
    }
}

private struct DailyTrendChartSection: View {
    let data: DailyStudyChartData
    let state: StatisticsViewState

    var body: some View {
        let now = state.now
        StatisticsChartSection(
            title: "stats.trend.title",
            subtitle: "stats.trend.dailySubtitle",
            legend: [
                (StatisticsStyle.studying, data.currentLabelKey(at: now)),
                (StatisticsStyle.average, data.previousLabelKey(at: now))
            ]
        ) {
            DailyStudyChart(data: data, now: now)
        }
    }
}

private struct PeriodTrendChartSection: View {
    let data: StudyTrendData
    let period: StatisticsPeriod

    var body: some View {
        StatisticsChartSection(
            title: "stats.trend.title",
            subtitle: period == .year ? "stats.trend.monthlySubtitle" : "stats.trend.subtitle",
            legend: trendLegend
        ) {
            StudyTrendChart(data: data)
                .id(period)
        }
    }

    private var trendLegend: [(Color, String)] {
        if period == .year { return [(StatisticsStyle.studying, "stats.kind.studying")] }
        return [
            (StatisticsStyle.studying, "stats.kind.studying"),
            (StatisticsStyle.average, "stats.trend.average")
        ]
    }
}
