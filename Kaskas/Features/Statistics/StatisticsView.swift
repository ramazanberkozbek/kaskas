import Charts
import Combine
import SwiftUI

struct StatisticsView: View {
    let controller: SessionController

    @State private var trendPeriod: StatisticsPeriod = .seven
    @State private var trendEndDate = Calendar.current.startOfDay(for: Date())
    @State private var distributionPeriod: StatisticsPeriod = .seven
    @State private var distributionEndDate = Calendar.current.startOfDay(for: Date())
    @State private var hourlyPeriod: HourlyPeriod = .day
    @State private var hourlyEndDate = Calendar.current.startOfDay(for: Date())
    @State private var hoveredDistributionDate: Date?
    @State private var hoveredHour: Int?
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var now = Date()
    @State private var intervals: [ActivityInterval] = []
    @State private var categorySummary: CategoryUsageSummary = .empty
    @State private var chartSnapshot: StatisticsChartSnapshot = .empty
    @State private var loaded = false
    @State private var loadedStart: Date?
    @State private var loadedEnd: Date?
    @Environment(\.colorScheme) private var colorScheme

    private let refreshClock = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("stats.today.title")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)

                        Text("stats.subtitle")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    summaryCards
                }

                chartSection(
                    title: "stats.trend.title",
                    subtitle: "stats.trend.subtitle",
                    legend: [
                        (StatisticsStyle.studying, "stats.kind.studying"),
                        (StatisticsStyle.average, "stats.trend.average")
                    ]
                ) {
                    StatisticsRangeControls(
                        period: $trendPeriod,
                        endDate: $trendEndDate,
                        now: now
                    )
                    StudyTrendChart(data: chartSnapshot.trend)
                }

                CategoryUsageView(
                    summary: categorySummary,
                    registry: controller.categoryRegistry,
                    storageFailed: controller.appUsage.storageFailed,
                    showsAppSegments: true
                )

                chartSection(
                    title: "stats.distribution.title",
                    subtitle: "stats.distribution.subtitle",
                    legend: ActivityKind.allCases.map { ($0.color, $0.labelKey) }
                ) {
                    StatisticsRangeControls(
                        period: $distributionPeriod,
                        endDate: $distributionEndDate,
                        now: now
                    )
                    distributionChart
                }

                chartSection(
                    title: "stats.hourly.title",
                    subtitle: "stats.hourly.subtitle",
                    legend: hourlyPeriod == .day
                        ? [(StatisticsStyle.computerInactive, "stats.kind.studying")]
                        : hourlyDays.map { (hourlyColor(for: $0.date), $0.date.formatted(.dateTime.weekday(.abbreviated).day())) }
                ) {
                    HourlyRangeControls(
                        period: $hourlyPeriod,
                        endDate: $hourlyEndDate,
                        now: now
                    )
                    hourlyChart
                }

                YearActivityHeatmap(
                    selectedYear: $selectedYear,
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
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { reload(force: true) }
        .onChange(of: trendPeriod) { _, _ in reload() }
        .onChange(of: trendEndDate) { _, _ in reload() }
        .onChange(of: distributionPeriod) { _, _ in hoveredDistributionDate = nil; reload() }
        .onChange(of: distributionEndDate) { _, _ in hoveredDistributionDate = nil; reload() }
        .onChange(of: hourlyPeriod) { _, _ in hoveredHour = nil; reload() }
        .onChange(of: hourlyEndDate) { _, _ in hoveredHour = nil; reload() }
        .onChange(of: selectedYear) { _, _ in reload() }
        .onReceive(refreshClock) { date in
            let previousToday = Calendar.current.startOfDay(for: now)
            now = date
            let today = Calendar.current.startOfDay(for: date)
            if trendEndDate == previousToday { trendEndDate = today }
            if distributionEndDate == previousToday { distributionEndDate = today }
            if hourlyEndDate == previousToday { hourlyEndDate = today }
            reload(force: true)
        }
    }

    private var today: DailyActivity {
        chartSnapshot.today
    }

    private var summaryCards: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 135), spacing: 10)], spacing: 10) {
            ForEach(ActivityKind.allCases, id: \.self) { kind in
                summaryCard(for: kind)
            }
        }
    }

    private func summaryCard(for kind: ActivityKind) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(kind.color)
                    .frame(width: 7, height: 7)
                Text(LocalizedStringKey(kind.labelKey))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(StatisticsDuration.label(today.duration(for: kind)))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(StatisticsStyle.panelFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.primary.opacity(0.08)))
    }

    private var trendWindow: (start: Date, end: Date) {
        trendPeriod.window(endingAt: trendEndDate)
    }

    private var distributionWindow: (start: Date, end: Date) {
        distributionPeriod.window(endingAt: distributionEndDate)
    }

    private var hourlyWindow: (start: Date, end: Date) {
        hourlyPeriod.window(endingAt: hourlyEndDate)
    }

    private var distributionDays: [DailyActivity] { chartSnapshot.distributionDays }
    private var hourlyDays: [DailyActivity] { chartSnapshot.hourlyDays }
    private var distributionPoints: [StatisticsChartSnapshot.DistributionPoint] { chartSnapshot.distributionPoints }

    private var distributionChart: some View {
        let selected = distributionDays.first { $0.date == hoveredDistributionDate }
        return Chart {
            ForEach(distributionPoints) { point in
                BarMark(
                    x: .value(String(localized: "stats.axis.day"), point.date, unit: .day),
                    y: .value(String(localized: "stats.axis.hours"), point.hours)
                )
                .foregroundStyle(point.kind.color)
                .cornerRadius(3)
            }
        }
        .chartLegend(.hidden)
        .chartYScale(domain: 0...24)
        .chartYAxis {
            AxisMarks(position: .trailing, values: [0, 6, 12, 18, 24])
        }
        .chartXAxis { AxisMarks(values: .stride(by: .day, count: distributionPeriod == .seven ? 1 : 5)) }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .onContinuousHover { phase in
                            hoveredDistributionDate = hoveredDate(for: phase, proxy: proxy, geometry: geometry, dates: distributionDays.map(\.date))
                        }
                    if let selected, let plotFrame = proxy.plotFrame,
                       let position = proxy.position(forX: chartDayCenter(selected.date)) {
                        let plot = geometry[plotFrame]
                        let x = plot.minX + position
                        let total = ActivityKind.allCases.reduce(0.0) { $0 + selected.duration(for: $1) }
                        hoverGuide(at: x, in: plot)
                        if total > 0, let y = proxy.position(forY: total / 3600) {
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(.white.opacity(0.8), lineWidth: 2)
                                .frame(
                                    width: plot.width / CGFloat(distributionDays.count) * 0.64,
                                    height: max(1, plot.maxY - plot.minY - y)
                                )
                                .position(x: x, y: plot.minY + y + (plot.maxY - plot.minY - y) / 2)
                                .allowsHitTesting(false)
                        }
                        VStack(alignment: .leading, spacing: 7) {
                            Text(selected.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.subheadline.weight(.semibold))
                            ForEach(ActivityKind.allCases, id: \.self) { kind in
                                tooltipRow(kind.labelKey, value: StatisticsDuration.label(selected.duration(for: kind)), color: kind.color)
                            }
                        }
                        .statisticsTooltip(width: 250)
                        .offset(x: tooltipOriginX(for: x, in: plot, width: 250), y: plot.minY + 8)
                        .allowsHitTesting(false)
                    }
                }
            }
        }
        .frame(height: 220)
    }

    private var hourlyPoints: [StatisticsChartSnapshot.HourlyPoint] { chartSnapshot.hourlyPoints }

    private var hourlyChart: some View {
        let points = hourlyPoints
        let selectedHour = hoveredHour
        let upperBound = chartSnapshot.hourlyUpperBound
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
                        Text("\(minutes) dk")
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
                        hoverGuide(at: x, in: plot)
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
                                tooltipRow("stats.total", value: StatisticsDuration.label(totalMinutes * 60), color: StatisticsStyle.computerInactive)
                                Divider()
                            }
                            if activePoints.isEmpty {
                                Text("stats.hourly.noFocus")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(activePoints) { point in
                                    tooltipRow(
                                        hourlyPeriod == .day ? "stats.kind.studying" : point.date.formatted(.dateTime.weekday(.abbreviated).day()),
                                        value: StatisticsDuration.label(point.minutes * 60),
                                        color: hourlyColor(for: point.date),
                                        localized: hourlyPeriod == .day
                                    )
                                }
                            }
                        }
                        .statisticsTooltip()
                        .offset(x: tooltipOriginX(for: x, in: plot), y: plot.minY + 8)
                        .allowsHitTesting(false)
                    }
                }
            }
        }
        .frame(height: 220)
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
        let index = hourlyDays.firstIndex { $0.date == date } ?? 0
        return palette[index % palette.count]
    }

    private func hoveredDate(
        for phase: HoverPhase,
        proxy: ChartProxy,
        geometry: GeometryProxy,
        dates: [Date]
    ) -> Date? {
        guard case .active(let location) = phase,
              let plotFrame = proxy.plotFrame else { return nil }
        let plot = geometry[plotFrame]
        guard plot.contains(location),
              let date = proxy.value(atX: location.x - plot.minX, as: Date.self) else { return nil }
        let day = Calendar.current.startOfDay(for: date)
        return dates.first { Calendar.current.isDate($0, inSameDayAs: day) }
    }

    private func chartDayCenter(_ date: Date) -> Date {
        guard let day = Calendar.current.dateInterval(of: .day, for: date) else { return date }
        return day.start.addingTimeInterval(day.duration / 2)
    }

    private func hoverGuide(at x: CGFloat, in plot: CGRect) -> some View {
        Path { path in
            path.move(to: CGPoint(x: x, y: plot.minY))
            path.addLine(to: CGPoint(x: x, y: plot.maxY))
        }
        .stroke(.primary.opacity(0.55), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        .allowsHitTesting(false)
    }

    private func tooltipOriginX(for x: CGFloat, in plot: CGRect, width: CGFloat = 230) -> CGFloat {
        let spacing: CGFloat = 14
        let preferred = x + spacing + width <= plot.maxX ? x + spacing : x - spacing - width
        return min(max(plot.minX, preferred), max(plot.minX, plot.maxX - width))
    }

    private func tooltipRow(_ label: String, value: String, color: Color, localized: Bool = true) -> some View {
        HStack(spacing: 7) {
            Circle().fill(color).frame(width: 7, height: 7)
            if localized {
                Text(LocalizedStringKey(label))
            } else {
                Text(label)
            }
            Spacer(minLength: 8)
            Text(value).fontWeight(.semibold).monospacedDigit()
        }
    }

    private func chartSection<Content: View>(
        title: String,
        subtitle: String? = nil,
        legend: [(Color, String)] = [],
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(title))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                if let subtitle {
                    Text(LocalizedStringKey(subtitle))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 14) {
                content()
                Divider()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(legend.indices, id: \.self) { index in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(legend[index].0)
                                    .frame(width: 7, height: 7)
                                Text(LocalizedStringKey(legend[index].1))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .padding(16)
            .background(StatisticsStyle.panelFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.09)))
        }
    }

    private func reload(force: Bool = false) {
        let trace = PerformanceTrace.begin("Statistics reload")
        defer { PerformanceTrace.end(trace) }
        let calendar = Calendar.current
        let trendStart = calendar.date(byAdding: .day, value: -6, to: trendWindow.start) ?? trendWindow.start
        let yearStart = calendar.date(from: DateComponents(year: selectedYear, month: 1, day: 1)) ?? now
        let start = min(trendStart, distributionWindow.start, hourlyWindow.start, yearStart)
        let end = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        let categoryEnd = calendar.date(byAdding: .day, value: 1, to: trendWindow.end) ?? now
        let coversWindow = loadedStart.map { start >= $0 } == true && loadedEnd.map { end <= $0 } == true
        if force || !coversWindow {
            intervals = controller.activityIntervals(from: start, to: end, now: now)
            loadedStart = start
            loadedEnd = end
            loaded = true
        }
        let appUsage = controller.appUsage.segments(from: trendWindow.start, to: categoryEnd, now: now)
        categorySummary = .make(intervals: intervals, usage: appUsage, from: trendWindow.start, to: categoryEnd)
        chartSnapshot = .make(intervals: intervals, now: now, trendWindow: trendWindow,
                              distributionWindow: distributionWindow, hourlyWindow: hourlyWindow, year: selectedYear)
    }
}

private extension View {
    func statisticsTooltip(width: CGFloat = 230) -> some View {
        self
            .font(.subheadline)
            .padding(12)
            .frame(width: width, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.primary.opacity(0.17)))
            .shadow(color: .black.opacity(0.22), radius: 12, y: 5)
    }
}

private struct StatisticsDateNavigator: View {
    @Binding var endDate: Date
    let startDate: Date
    let stepDays: Int
    let now: Date
    @State private var showingCalendar = false

    var body: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        ControlGroup {
            Button {
                endDate = calendar.date(byAdding: .day, value: -stepDays, to: endDate) ?? endDate
            } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel("stats.previousPeriod")

            Button {
                showingCalendar = true
            } label: {
                Text(rangeLabel)
                    .monospacedDigit()
                    .frame(minWidth: 100)
            }
            .accessibilityLabel("stats.chooseDate")
            .popover(isPresented: $showingCalendar) {
                DatePicker("stats.chooseDate", selection: $endDate, in: ...today, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()
            }

            Button {
                let next = calendar.date(byAdding: .day, value: stepDays, to: endDate) ?? endDate
                endDate = min(today, next)
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(endDate >= today)
            .accessibilityLabel("stats.nextPeriod")
        }
    }

    private var rangeLabel: String {
        let start = startDate.formatted(.dateTime.day().month(.abbreviated))
        let end = endDate.formatted(.dateTime.day().month(.abbreviated))
        return stepDays == 1 ? end : "\(start)–\(end)"
    }
}

struct StatisticsRangeControls: View {
    @Binding var period: StatisticsPeriod
    @Binding var endDate: Date
    let now: Date

    var body: some View {
        HStack(spacing: 10) {
            StatisticsDateNavigator(
                endDate: $endDate,
                startDate: period.window(endingAt: endDate).start,
                stepDays: period.rawValue,
                now: now
            )
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
    }
}

private struct HourlyRangeControls: View {
    @Binding var period: HourlyPeriod
    @Binding var endDate: Date
    let now: Date

    var body: some View {
        HStack(spacing: 10) {
            StatisticsDateNavigator(
                endDate: $endDate,
                startDate: period.window(endingAt: endDate).start,
                stepDays: period.rawValue,
                now: now
            )
            Spacer(minLength: 8)
            Picker("stats.period", selection: $period) {
                ForEach(HourlyPeriod.allCases) { item in
                    Text(LocalizedStringKey(item.labelKey)).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 132)
        }
    }
}
