import Combine
import SwiftUI

struct DashboardView: View {
    let controller: SessionController

    @Bindable var state: DashboardViewState
    @State private var selectedSession: DashboardCategorySnapshot.Session?
    @State private var showingCalendar = false
    @State private var annotationsRevision = 0
    @State private var refreshTask: Task<Void, Never>?

    @Environment(\.colorScheme) private var colorScheme

    private let clock = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    private var period: DashboardPeriod { state.period }
    private var endDate: Date { state.endDate }
    private var now: Date { state.now }
    private var chartSnapshot: DashboardChartSnapshot { state.snapshot?.chart ?? .empty }
    private var window: (start: Date, end: Date) {
        let end = Calendar.current.startOfDay(for: endDate)
        let start = Calendar.current.date(byAdding: .day, value: -6, to: end) ?? end
        return (start, end)
    }
    private var days: [DailyActivity] { chartSnapshot.days }
    private var weekTotal: TimeInterval { days.reduce(0) { $0 + $1.studying } }
    private var categorySnapshot: DashboardCategorySnapshot {
        (period == .today ? state.snapshot?.day : state.snapshot?.week) ?? .empty
    }
    private var sessions: [DashboardCategorySnapshot.Session] { categorySnapshot.sessions }
    private var visibleSessions: [DashboardCategorySnapshot.Session] {

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

    private func groupedSessions(_ visibleSessions: [DashboardCategorySnapshot.Session]) -> [(date: Date, sessions: [DashboardCategorySnapshot.Session])] {
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
        let visibleSessions = visibleSessions
        let groupedSessions = period == .week ? groupedSessions(visibleSessions) : []
        return ScrollView {
            VStack(alignment: .leading, spacing: SettingsPageLayout.sectionSpacing) {
                SettingsPaneHeader(title: "settings.sidebar.dashboard")

                VStack(spacing: 14) {
                    rangeControls
                    if state.snapshot != nil {
                        if period == .today {
                            DailyStudyChart(data: chartSnapshot.today, now: now)
                        } else {
                            StudyTrendChart(data: chartSnapshot.trend)
                        }
                        Divider()
                        HStack(spacing: 18) {
                            if period == .today {
                                legend(
                                    LocalizedStringKey(chartSnapshot.today.currentLabelKey(at: now)),
                                    color: StatisticsStyle.studying
                                )
                                legend(
                                    LocalizedStringKey(chartSnapshot.today.previousLabelKey(at: now)),
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
                            Text(StatisticsDuration.label(period == .today ? (days.last?.studying ?? 0) : weekTotal, locale: controller.locale))
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                        }
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 220)
                    }
                }
                .dashboardPanel(colorScheme)

                if state.snapshot != nil {
                    CategoryUsageView(summary: categorySnapshot.usage, registry: controller.categoryRegistry,
                        storageFailed: controller.appUsage.storageFailed, showsAppSegments: true,
                        minimumVisibleShare: 0.05)

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
                }

                if controller.activityStorageFailed {
                    Label("stats.storageWarning", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .settingsPageContent()
        }
        .scrollIndicators(.hidden)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(item: $selectedSession) { selected in
            let item = sessions.first { $0.id == selected.id } ?? selected
            SessionDetailView(
                session: item.value,
                controller: controller,
                summary: item.summary,
                onSave: {
                    annotationsRevision += 1
                    reload()
                }
            )
            .environment(\.locale, controller.locale)
        }
        .onChange(of: controller.annotationsRevision) { _, _ in
            annotationsRevision = controller.annotationsRevision
            reload()
        }
        .onAppear {
            state.updateClock(to: Date())
            reload()
        }
        .onDisappear { refreshTask?.cancel() }
        .onChange(of: controller.historyRevision) { _, _ in reload() }
        .onChange(of: controller.categoryRegistry.revision) { _, _ in reload() }
        .onChange(of: controller.appUsage.exclusions.revision) { _, _ in reload() }
        .onChange(of: endDate) { _, newDate in
            let normalized = Calendar.current.startOfDay(for: newDate)
            if endDate != normalized {
                state.endDate = normalized
            }
            reload()
        }
        .onReceive(clock) { date in
            state.updateClock(to: date)
            reload()
        }
    }

    private var rangeControls: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        return HStack(spacing: 10) {
            ControlGroup {
                Button {
                    state.endDate = calendar.date(byAdding: .day, value: -period.rawValue, to: endDate) ?? endDate
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
                    DatePicker("stats.chooseDate", selection: $state.endDate, in: ...today, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .padding()
                        .environment(\.locale, controller.locale)
                }

                Button {
                    let next = calendar.date(byAdding: .day, value: period.rawValue, to: endDate) ?? endDate
                    state.endDate = min(today, next)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(endDate >= today)
                .accessibilityLabel("stats.nextPeriod")
            }
            Spacer(minLength: 8)
            Picker("stats.period", selection: $state.period) {
                Text("dashboard.period.today").tag(DashboardPeriod.today)
                Text("stats.period.seven").tag(DashboardPeriod.week)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 112)
            .background {
                // The native picker is 24 pt tall. Extend each segment's hit
                // region vertically without resizing it or intercepting its
                // own mouse tracking, keyboard navigation or accessibility.
                HStack(spacing: 0) {
                    periodHitArea(.today)
                    periodHitArea(.week)
                }
                .frame(height: 44)
                .accessibilityHidden(true)
            }
        }
    }

    private func periodHitArea(_ value: DashboardPeriod) -> some View {
        Button {
            state.period = value
        } label: {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
    }

    private var rangeLabel: String {
        let locale = controller.locale
        if period == .today { return endDate.formatted(.dateTime.day().month(.abbreviated).locale(locale)) }
        let start = window.start.formatted(.dateTime.day().month(.abbreviated).locale(locale))
        let end = window.end.formatted(.dateTime.day().month(.abbreviated).locale(locale))
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
            registry: controller.categoryRegistry, isOngoing: session.isOngoing(startedAt: controller.activeStudyingStartedAt),
            locale: controller.locale)
        let timeRange = "\(formatTime(session.startedAt))–\(formatTime(session.endedAt))"
        let durationLabel = SessionDuration.minutesLabel(session.focusedDuration, locale: controller.locale)
        let categoryTitle = (category.mixedBreakdown?.isEmpty == false) ? category.mixedBreakdown! : category.title
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
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
                Spacer(minLength: 8)
                Label {
                    Text(categoryTitle)
                        .foregroundStyle(.primary)
                } icon: {
                    Image(systemName: category.symbol)
                        .foregroundStyle(category.color)
                }
                .font(.caption.weight(.medium))
                .lineLimit(1)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }

            if !annotation.note.isEmpty {
                Text(annotation.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func reload() {
        refreshTask?.cancel()
        let date = endDate
        let refreshNow = now
        let calendar = Calendar.current
        let weekStart = window.start
        let selectedDay = calendar.startOfDay(for: date)
        let start = calendar.date(byAdding: .day, value: -6, to: weekStart) ?? weekStart
        let sessionEnd = calendar.date(byAdding: .day, value: 1, to: selectedDay) ?? refreshNow
        let end = min(sessionEnd, refreshNow)
        let exclusions = controller.appUsage.exclusions.snapshot()
        refreshTask = Task {
            let trace = PerformanceTrace.begin("Dashboard refresh")
            defer { PerformanceTrace.end(trace) }
            let intervals = await controller.activityIntervalsAsync(from: start, to: end, now: refreshNow)
            guard !Task.isCancelled else { return }
            let usage = await controller.appUsage.segmentsAsync(from: start, to: end, now: refreshNow)
            guard !Task.isCancelled else { return }
            let excluded = await controller.appUsage.excludedIntervalsAsync(from: start, to: end, now: refreshNow)
            guard !Task.isCancelled else { return }
            let breaks = await controller.breakEntriesAsync(from: weekStart, through: end)
            guard !Task.isCancelled else { return }
            guard let snapshot = try? await DashboardRefreshSnapshot.make(intervals: intervals, usage: usage, breaks: breaks,
                date: date, weekStart: weekStart, sessionEnd: sessionEnd, calendar: calendar, excluded: excluded, exclusions: exclusions) else { return }
            guard !Task.isCancelled else { return }
            state.snapshot = snapshot
            if let selected = selectedSession {
                selectedSession = (snapshot.day.sessions + snapshot.week.sessions).first { $0.id == selected.id }
            }
        }
    }

    private func dayHeader(_ date: Date, totalDuration: TimeInterval, isFirst: Bool) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(dayHeaderTitle(date))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
            Spacer()
            Text(SessionDuration.label(totalDuration, locale: controller.locale))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 4)
        .padding(.top, isFirst ? 0 : 4)
        .padding(.bottom, 6)
    }

    private func dayHeaderTitle(_ date: Date) -> String {
        let locale = controller.locale
        let calendar = Calendar.current
        let dayFormatted = date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated).locale(locale))
        if calendar.isDateInToday(date) {
            return "\(localizedString("dashboard.today", locale: locale)) · \(dayFormatted)"
        } else if calendar.isDateInYesterday(date) {
            return "\(localizedString("dashboard.yesterday", locale: locale)) · \(dayFormatted)"
        }
        return dayFormatted
    }

    private func formatTime(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).locale(controller.locale))
    }
}

enum SessionDuration {
    static func minutesLabel(_ duration: TimeInterval, locale: Locale = AppLanguage.currentLocale) -> String {
        let value = max(0, duration)
        if value < 60 {
            return localizedString("dashboard.duration.underMinute", locale: locale)
        }
        let minutes = max(1, Int((value / 60).rounded()))
        let format = Measurement<UnitDuration>.FormatStyle(
            width: .abbreviated,
            usage: .asProvided
        ).locale(locale)
        let isTurkish = locale.language.languageCode?.identifier == "tr" || locale.identifier.hasPrefix("tr")
        let label = Measurement(value: Double(minutes), unit: UnitDuration.minutes).formatted(format)
        return isTurkish ? label.replacingOccurrences(of: "dk.", with: "dk") : label
    }

    static func label(_ duration: TimeInterval, locale: Locale = AppLanguage.currentLocale) -> String {
        duration < 60 ? localizedString("dashboard.duration.underMinute", locale: locale) : StatisticsDuration.label(duration, locale: locale)
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
            .padding(SettingsPageLayout.cardInset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(StatisticsStyle.panelFill(for: scheme), in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.primary.opacity(0.08))
                    .allowsHitTesting(false)
            }
    }
}
