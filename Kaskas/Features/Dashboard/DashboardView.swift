import Combine
import SwiftUI

struct DashboardView: View {
    let controller: SessionController

    @State private var period: DashboardPeriod = .today
    @State private var endDate = Calendar.current.startOfDay(for: Date())
    @State private var now = Date()
    @State private var intervals: [ActivityInterval] = []
    @State private var breakEntries: [BreakHistoryEntry] = []
    @State private var selectedSession: StudySession?
    @State private var showingCalendar = false
    @State private var showShortSessions = false
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
    private var days: [DailyActivity] {
        ActivityStatistics.days(from: window.start, through: window.end, intervals: intervals)
    }
    private var weekTotal: TimeInterval { days.reduce(0) { $0 + $1.studying } }
    private var sessions: [StudySession] {
        let today = Calendar.current.startOfDay(for: now)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? now
        let todayIntervals = intervals.filter {
            $0.kind == .studying && $0.startedAt >= today && $0.startedAt < end
        }
        return Array(StudySessionGrouping.group(todayIntervals, breakEntries: breakEntries).reversed())
    }
    private var visibleSessions: [StudySession] {
#if DEBUG
        if showsSessionDebug { return sessions }
#endif
        _ = annotationsRevision
        _ = controller.annotationsRevision
        return sessions.filter { session in
            let annotation = controller.annotation(for: session)
            let hasAnnotation = !annotation.note.isEmpty || !annotation.category.isEmpty
            return session.isVisible(
                showShortSessions: showShortSessions,
                hasAnnotation: hasAnnotation,
                activeStartedAt: controller.activeStudyingStartedAt
            )
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(spacing: 14) {
                    rangeControls
                    if period == .today {
                            DashboardTodayChart(date: endDate, intervals: intervals)
                        } else {
                            StudyTrendChart(days: days, intervals: intervals)
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

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center, spacing: 12) {
                        sectionHeading("dashboard.sessions.title", subtitle: "dashboard.sessions.subtitle", symbol: "list.bullet.rectangle")
                        Spacer(minLength: 8)
                        Toggle("dashboard.sessions.showShort", isOn: $showShortSessions)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                    }
                    if visibleSessions.isEmpty {
                        Text(sessions.isEmpty ? "dashboard.sessions.empty" : "dashboard.sessions.shortOnly")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 90, alignment: .center)
                            .dashboardPanel(colorScheme)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(visibleSessions) { session in
                                Button { selectedSession = session } label: { sessionRow(session) }
                                    .buttonStyle(.plain)
                                if session.id != visibleSessions.last?.id { Divider() }
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
        .sheet(item: $selectedSession) { session in
            SessionDetailView(
                session: session,
                controller: controller,
                allIntervals: intervals,
                nextSession: nextSession(after: session),
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
        .onChange(of: endDate) { _, _ in reload() }
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

    private func sectionHeading(_ title: LocalizedStringKey, subtitle: LocalizedStringKey, symbol: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(StatisticsStyle.studying)
                .frame(width: 32, height: 32)
                .background(StatisticsStyle.studying.opacity(0.15), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .tracking(1.1)
                Text(subtitle)
                    .font(.caption)
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

    private func sessionRow(_ session: StudySession) -> some View {
        let annotation = controller.annotation(for: session)
        let timeRange = "\(formatTime(session.startedAt))–\(formatTime(session.endedAt))"
        let durationLabel = SessionDuration.minutesLabel(session.focusedDuration)
        return HStack(spacing: 14) {
            Image(systemName: "timer")
                .foregroundStyle(StatisticsStyle.studying)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
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
#if DEBUG
                if showsSessionDebug {
                    DashboardSessionDebugRow(
                        session: session,
                        allIntervals: intervals,
                        nextSession: nextSession(after: session),
                        isHiddenByShortFilter: !showShortSessions
                            && session.focusedDuration < StudySessionGrouping.minimumDefaultDuration
                            && annotation.note.isEmpty
                            && annotation.category.isEmpty,
                        controller: controller
                    )
                }
#endif
                if !annotation.note.isEmpty {
                    Text(annotation.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if !annotation.category.isEmpty {
                Text(annotation.category)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func reload() {
        let averageStart = Calendar.current.date(byAdding: .day, value: -6, to: window.start) ?? window.start
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: endDate) ?? endDate
        let today = Calendar.current.startOfDay(for: now)
        let start = min(averageStart, yesterday, today)
        intervals = controller.activityIntervals(from: start, to: now, now: now)
        breakEntries = controller.breakEntries(from: today, through: now)
    }

    private func nextSession(after session: StudySession) -> StudySession? {
        let ordered = sessions
        guard let index = ordered.firstIndex(where: { $0.id == session.id }), index > 0 else { return nil }
        return ordered[index - 1]
    }

    private func formatTime(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    }
}

private enum DashboardPeriod: Int {
    case today = 1
    case week = 7
}

private struct SessionDetailView: View {
    let session: StudySession
    let controller: SessionController
    let allIntervals: [ActivityInterval]
    let nextSession: StudySession?
    let onSave: (() -> Void)?

    @State private var category: String
    @State private var note: String
    @Environment(\.dismiss) private var dismiss
#if DEBUG
    @AppStorage("debugModeEnabled") private var debugModeEnabled = false
    @AppStorage("debugSessionDetailsEnabled") private var debugSessionDetailsEnabled = false
#endif

    init(
        session: StudySession,
        controller: SessionController,
        allIntervals: [ActivityInterval],
        nextSession: StudySession?,
        onSave: (() -> Void)? = nil
    ) {
        self.session = session
        self.controller = controller
        self.allIntervals = allIntervals
        self.nextSession = nextSession
        self.onSave = onSave
        let annotation = controller.annotation(for: session)
        _category = State(initialValue: annotation.category)
        _note = State(initialValue: annotation.note)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("dashboard.session.detail").font(.title2.weight(.semibold))
            Text("\(session.startedAt.formatted(date: .abbreviated, time: .shortened)) – \(session.endedAt.formatted(date: .omitted, time: .shortened))")
                .foregroundStyle(.secondary)
            Text("\(SessionDuration.label(session.focusedDuration)) \(String(localized: "dashboard.session.focused")) · \(session.interruptionCount) \(String(localized: "dashboard.session.interruptions"))")
                .font(.subheadline.weight(.medium))
            Divider()
            Text("dashboard.session.parts").font(.subheadline.weight(.semibold))
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(session.segments) { segment in
                        HStack {
                            Text("\(segment.start.formatted(date: .omitted, time: .shortened))–\(segment.end.formatted(date: .omitted, time: .shortened))")
                            Spacer()
                            Text(SessionDuration.label(segment.duration))
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                    }
                }
            }
            .frame(maxHeight: 150)
#if DEBUG
            if debugModeEnabled && debugSessionDetailsEnabled {
                SessionDebugDetailView(
                    session: session,
                    allIntervals: allIntervals,
                    nextSession: nextSession,
                    controller: controller
                )
            }
#endif
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    TextField("dashboard.session.category", text: $category)
                    Menu {
                        ForEach(controller.categoryRegistry.categories) { cat in
                            Button {
                                category = cat.name
                            } label: {
                                Label(cat.name, systemImage: cat.iconName)
                            }
                        }
                    } label: {
                        Image(systemName: "tag")
                            .font(.caption)
                    }
                    .menuStyle(.borderlessButton)
                    .help("Kayıtlı kategorilerden seç")
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(controller.categoryRegistry.categories) { cat in
                            Button {
                                category = cat.name
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: cat.iconName)
                                        .font(.system(size: 8))
                                    Text(cat.name)
                                        .font(.system(size: 10))
                                }
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(
                                    category == cat.name
                                        ? cat.color.opacity(0.18)
                                        : Color.primary.opacity(0.04),
                                    in: Capsule()
                                )
                                .overlay(
                                    Capsule()
                                        .strokeBorder(
                                            category == cat.name ? cat.color.opacity(0.6) : Color.clear,
                                            lineWidth: 1
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("dashboard.session.note").font(.subheadline.weight(.medium))
                TextEditor(text: $note)
                    .frame(minHeight: 130)
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.primary.opacity(0.12)))
            }
            HStack {
                Spacer()
                Button("dashboard.session.cancel") { dismiss() }
                Button("dashboard.session.save") {
                    controller.save(
                        annotation: SessionAnnotation(
                            category: category.trimmingCharacters(in: .whitespacesAndNewlines),
                            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
                        ),
                        for: session
                    )
                    onSave?()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: detailWidth)
    }

    private var detailWidth: CGFloat {
#if DEBUG
        debugModeEnabled && debugSessionDetailsEnabled ? 620 : 430
#else
        430
#endif
    }
}

private enum SessionDuration {
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
