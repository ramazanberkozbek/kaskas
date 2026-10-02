import Combine
import SwiftUI

struct DashboardView: View {
    let controller: SessionController

    @State private var period: DashboardPeriod = .today
    @State private var endDate = Calendar.current.startOfDay(for: Date())
    @State private var now = Date()
    @State private var intervals: [ActivityInterval] = []
    @State private var categorySnapshot: DashboardCategorySnapshot = .empty
    @State private var chartSnapshot: DashboardChartSnapshot = .empty
    @State private var selectedSession: DashboardCategorySnapshot.Session?
    @State private var showingCalendar = false
    @State private var annotationsRevision = 0
#if DEBUG
    @AppStorage("debugModeEnabled") private var debugModeEnabled = false
    @AppStorage("debugSessionDetailsEnabled") private var debugSessionDetailsEnabled = false

    private var showsSessionDebug: Bool { debugModeEnabled && debugSessionDetailsEnabled }
#endif
    @Environment(\.colorScheme) private var colorScheme

    private let clock = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    private var window: (start: Date, end: Date) {
        let end = Calendar.current.startOfDay(for: endDate)
        let start = Calendar.current.date(byAdding: .day, value: -6, to: end) ?? end
        return (start, end)
    }
    private var days: [DailyActivity] { chartSnapshot.days }
    private var weekTotal: TimeInterval { days.reduce(0) { $0 + $1.studying } }
    private var sessions: [DashboardCategorySnapshot.Session] { categorySnapshot.sessions }
    private var visibleSessions: [DashboardCategorySnapshot.Session] {
#if DEBUG
        if showsSessionDebug { return sessions }
#endif
        _ = annotationsRevision
        _ = controller.annotationsRevision
        return sessions.filter { item in
            let session = item.value
            let annotation = controller.annotation(for: session)
            let hasAnnotation = !annotation.isEmpty
            return session.isVisible(
                showShortSessions: false,
                hasAnnotation: hasAnnotation,
                activeStartedAt: controller.activeStudyingStartedAt
            )
        }
    }

    private var groupedSessions: [(date: Date, sessions: [DashboardCategorySnapshot.Session])] {
        let calendar = Calendar.current
        var groups: [(date: Date, sessions: [DashboardCategorySnapshot.Session])] = []
        for item in visibleSessions {
            let day = calendar.startOfDay(for: item.value.startedAt)
            if let lastIndex = groups.indices.last, groups[lastIndex].date == day {
                groups[lastIndex].sessions.append(item)
            } else {
                groups.append((date: day, sessions: [item]))
            }
        }
        return groups
    }

    private var isSelectedDayToday: Bool {
        Calendar.current.isDateInToday(endDate)
    }

    private var sessionsSubtitle: LocalizedStringKey {
        if period == .week {
            return "dashboard.sessions.subtitle.week"
        } else if isSelectedDayToday {
            return "dashboard.sessions.subtitle"
        } else {
            return "dashboard.sessions.subtitle.selected"
        }
    }

    private var sessionsEmptyText: LocalizedStringKey {
        if period == .week {
            return "dashboard.sessions.empty.week"
        } else if isSelectedDayToday {
            return "dashboard.sessions.empty"
        } else {
            return "dashboard.sessions.empty.selected"
        }
    }

    private var sessionsShortOnlyText: LocalizedStringKey {
        if period == .week {
            return "dashboard.sessions.shortOnly.week"
        } else if isSelectedDayToday {
            return "dashboard.sessions.shortOnly"
        } else {
            return "dashboard.sessions.shortOnly.selected"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(spacing: 14) {
                    rangeControls
                    if period == .today {
                            DashboardTodayChart(data: chartSnapshot.today)
                        } else {
                            StudyTrendChart(data: chartSnapshot.trend)
                        }
                        Divider()
                        HStack(spacing: 18) {
                            if period == .today {
                                legend(
                                    Calendar.current.isDateInToday(endDate) ? "dashboard.today" : "dashboard.day.selected",
                                    color: StatisticsStyle.studying
                                )
                                legend(
                                    Calendar.current.isDateInToday(endDate) ? "dashboard.yesterday" : "dashboard.day.previous",
                                    color: StatisticsStyle.average
                                )
                            } else {
                                legend("stats.kind.studying", color: StatisticsStyle.studying)
                                legend("stats.trend.average", color: StatisticsStyle.average)
                            }
                            Spacer(minLength: 0)
                            Text(period == .today ? "dashboard.day.total" : "dashboard.week.total")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(StatisticsDuration.label(period == .today ? (days.last?.studying ?? 0) : weekTotal))
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                        }
                    }
                    .dashboardPanel(colorScheme)

                CategoryUsageView(summary: categorySnapshot.usage, registry: controller.categoryRegistry,
                    storageFailed: controller.appUsage.storageFailed, showsAppSegments: true)

                VStack(alignment: .leading, spacing: 8) {
                    sectionHeading("dashboard.sessions.title", subtitle: sessionsSubtitle)
                    if visibleSessions.isEmpty {
                        Text(sessions.isEmpty ? sessionsEmptyText : sessionsShortOnlyText)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 90, alignment: .center)
                            .dashboardPanel(colorScheme)
                    } else {
                        LazyVStack(spacing: 0) {
                            if period == .week {
                                ForEach(groupedSessions, id: \.date) { group in
                                    VStack(alignment: .leading, spacing: 0) {
                                        dayHeader(
                                            group.date,
                                            totalDuration: group.sessions.reduce(0) { $0 + $1.value.focusedDuration },
                                            isFirst: group.date == groupedSessions.first?.date
                                        )
                                        ForEach(group.sessions) { session in
                                            Button { selectedSession = session } label: { sessionRow(session) }
                                                .buttonStyle(.plain)
                                            if session.id != group.sessions.last?.id {
                                                Divider()
                                            }
                                        }
                                        if group.date != groupedSessions.last?.date {
                                            Divider()
                                                .padding(.vertical, 8)
                                        }
                                    }
                                }
                            } else {
                                ForEach(visibleSessions) { session in
                                    Button { selectedSession = session } label: { sessionRow(session) }
                                        .buttonStyle(.plain)
                                    if session.id != visibleSessions.last?.id { Divider() }
                                }
                            }
                        }
                        .dashboardPanel(colorScheme)
                    }
                }

                if controller.activityStorageFailed {
                    Label("stats.storageWarning", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(item: $selectedSession) { selected in
            let item = sessions.first { $0.id == selected.id } ?? selected
            SessionDetailView(
                session: item.value,
                controller: controller,
                summary: item.summary,
                allIntervals: intervals,
                nextSession: nextSession(after: item.value),
                onSave: {
                    annotationsRevision += 1
                    reload()
                }
            )
        }
        .onChange(of: controller.annotationsRevision) { _, _ in
            annotationsRevision = controller.annotationsRevision
            reload()
        }
        .onAppear(perform: reload)
        .onChange(of: period) { _, _ in reload() }
        .onChange(of: endDate) { _, newDate in
            let normalized = Calendar.current.startOfDay(for: newDate)
            if endDate != normalized {
                endDate = normalized
            }
            reload()
        }
        .onReceive(clock) { date in
            let oldToday = Calendar.current.startOfDay(for: now)
            now = date
            if endDate == oldToday { endDate = Calendar.current.startOfDay(for: date) }
            reload()
        }
    }

    private var rangeControls: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        return HStack(spacing: 10) {
            ControlGroup {
                Button {
                    endDate = calendar.date(byAdding: .day, value: -period.rawValue, to: endDate) ?? endDate
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
                    let next = calendar.date(byAdding: .day, value: period.rawValue, to: endDate) ?? endDate
                    endDate = min(today, next)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(endDate >= today)
                .accessibilityLabel("stats.nextPeriod")
            }
            Spacer(minLength: 8)
            Picker("stats.period", selection: $period) {
                Text("dashboard.period.today").tag(DashboardPeriod.today)
                Text("stats.period.seven").tag(DashboardPeriod.week)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 112)
        }
    }

    private var rangeLabel: String {
        if period == .today { return endDate.formatted(.dateTime.day().month(.abbreviated)) }
        let start = window.start.formatted(.dateTime.day().month(.abbreviated))
        let end = window.end.formatted(.dateTime.day().month(.abbreviated))
        return "\(start)–\(end)"
    }

    private func sectionHeading(_ title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func legend(_ title: LocalizedStringKey, color: Color) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 13, height: 5)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func sessionRow(_ item: DashboardCategorySnapshot.Session) -> some View {
        let session = item.value
        let annotation = controller.annotation(for: session)
        let summary = item.summary
        let category = SessionCategoryPresentation(selection: .init(annotation: annotation), summary: summary,
            registry: controller.categoryRegistry, isOngoing: session.isOngoing(startedAt: controller.activeStudyingStartedAt))
        let timeRange = "\(formatTime(session.startedAt))–\(formatTime(session.endedAt))"
        let durationLabel = SessionDuration.minutesLabel(session.focusedDuration)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 14) {
                Image(systemName: "timer")
                    .foregroundStyle(StatisticsStyle.studying)
                    .frame(width: 30)
                HStack(alignment: .center, spacing: 10) {
                    Text(durationLabel)
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .frame(width: 50, alignment: .leading)
                    HStack(spacing: 6) {
                        Text(timeRange)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        if session.isOngoing(startedAt: controller.activeStudyingStartedAt) {
                            BlinkingDotView()
                        }
                    }
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 4) {
                    Label(category.title, systemImage: category.symbol)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(category.color)
                        .lineLimit(1)
                    if let breakdown = category.mixedBreakdown {
                        Text(breakdown)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: 220, alignment: .trailing)
                .help(category.explanation)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
#if DEBUG
            if showsSessionDebug {
                DashboardSessionDebugRow(
                    session: session,
                    allIntervals: intervals,
                    nextSession: nextSession(after: session),
                    isHiddenByShortFilter: session.focusedDuration < StudySessionGrouping.minimumDefaultDuration
                        && annotation.note.isEmpty
                        && !annotation.hasManualCategory,
                    controller: controller
                )
                .padding(.leading, 44)
            }
#endif
            if !annotation.note.isEmpty {
                Text(annotation.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 44)
            }
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func reload() {
        let calendar = Calendar.current
        let selectedDay = calendar.startOfDay(for: endDate)
        let averageStart = calendar.date(byAdding: .day, value: -6, to: window.start) ?? window.start
        let yesterday = calendar.date(byAdding: .day, value: -1, to: selectedDay) ?? selectedDay
        let today = calendar.startOfDay(for: now)
        let start = min(averageStart, yesterday, today, selectedDay)
        intervals = controller.activityIntervals(from: start, to: now, now: now)
        let appUsage = controller.appUsage.segments(from: start, to: now, now: now)

        let sessionStart = period == .today ? selectedDay : window.start
        let sessionEnd = calendar.date(byAdding: .day, value: 1, to: period == .today ? selectedDay : window.end) ?? now
        let breakEnd = min(sessionEnd, now)
        let breakEntries = controller.breakEntries(from: sessionStart, through: breakEnd)
        let targetIntervals = intervals.filter {
            $0.kind == .studying && $0.startedAt >= sessionStart && $0.startedAt < sessionEnd
        }
        let sessions = Array(StudySessionGrouping.group(targetIntervals, breakEntries: breakEntries).reversed())

        categorySnapshot = .make(intervals: intervals, appUsage: appUsage, sessions: sessions,
                                 from: sessionStart, to: sessionEnd)
        chartSnapshot = .make(intervals: intervals, date: endDate, weekStart: window.start)
    }

    private func nextSession(after session: StudySession) -> StudySession? {
        let ordered = sessions
        guard let index = ordered.firstIndex(where: { $0.id == session.id }), index > 0 else { return nil }
        return ordered[index - 1].value
    }

    private func dayHeader(_ date: Date, totalDuration: TimeInterval, isFirst: Bool) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(dayHeaderTitle(date))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
            Spacer()
            Text(SessionDuration.label(totalDuration))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 4)
        .padding(.top, isFirst ? 0 : 4)
        .padding(.bottom, 6)
    }

    private func dayHeaderTitle(_ date: Date) -> String {
        let calendar = Calendar.current
        let dayFormatted = date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
        if calendar.isDateInToday(date) {
            return "\(String(localized: "dashboard.today")) · \(dayFormatted)"
        } else if calendar.isDateInYesterday(date) {
            return "\(String(localized: "dashboard.yesterday")) · \(dayFormatted)"
        }
        return dayFormatted
    }

    private func formatTime(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    }
}

private enum DashboardPeriod: Int {
    case today = 1
    case week = 7
}

enum SessionDuration {
    static func minutesLabel(_ duration: TimeInterval) -> String {
        let value = max(0, duration)
        if value < 60 {
            return "<1 dk."
        }
        let minutes = max(1, Int((value / 60).rounded()))
        return Measurement(value: Double(minutes), unit: UnitDuration.minutes)
            .formatted(.measurement(width: .abbreviated, numberFormatStyle: .number.precision(.fractionLength(0))))
    }

    static func label(_ duration: TimeInterval) -> String {
        duration < 60 ? "<1 dk." : StatisticsDuration.label(duration)
    }
}

private struct BlinkingDotView: View {
    @State private var isVisible = true

    var body: some View {
        Circle()
            .fill(StatisticsStyle.studying)
            .frame(width: 7, height: 7)
            .opacity(isVisible ? 1.0 : 0.2)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isVisible)
            .onAppear {
                isVisible = false
            }
            .accessibilityLabel(Text("dashboard.session.now"))
    }
}

private extension View {
    func dashboardPanel(_ scheme: ColorScheme) -> some View {
        self
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(StatisticsStyle.panelFill(for: scheme), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.primary.opacity(0.08)))
    }
}
