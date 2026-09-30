import Combine
import SwiftUI

struct DashboardView: View {
    let controller: SessionController

    @State private var period: StatisticsPeriod = .seven
    @State private var endDate = Calendar.current.startOfDay(for: Date())
    @State private var now = Date()
    @State private var intervals: [ActivityInterval] = []
    @State private var selectedSession: ActivityInterval?
    @Environment(\.colorScheme) private var colorScheme

    private let clock = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    private var window: (start: Date, end: Date) { period.window(endingAt: endDate) }
    private var days: [DailyActivity] {
        ActivityStatistics.days(from: window.start, through: window.end, intervals: intervals)
    }
    private var sessions: [ActivityInterval] {
        let end = Calendar.current.date(byAdding: .day, value: 1, to: window.end) ?? now
        return intervals.filter {
            $0.kind == .studying && $0.endedAt > window.start && $0.startedAt < end
        }.sorted { $0.startedAt > $1.startedAt }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Dashboard").font(.largeTitle.weight(.bold))
                    Text("dashboard.subtitle").font(.callout).foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    sectionHeading("stats.trend.title", subtitle: "stats.trend.subtitle", symbol: "chart.xyaxis.line")
                    VStack(spacing: 14) {
                        StatisticsRangeControls(period: $period, endDate: $endDate, now: now)
                        StudyTrendChart(days: days, intervals: intervals)
                        Divider()
                        HStack(spacing: 18) {
                            legend("stats.kind.studying", color: StatisticsStyle.studying)
                            legend("stats.trend.average", color: StatisticsStyle.average)
                            Spacer(minLength: 0)
                        }
                    }
                    .dashboardPanel(colorScheme)
                }

                VStack(alignment: .leading, spacing: 10) {
                    sectionHeading("dashboard.sessions.title", subtitle: "dashboard.sessions.subtitle", symbol: "list.bullet.rectangle")
                    if sessions.isEmpty {
                        Text("dashboard.sessions.empty")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 90, alignment: .center)
                            .dashboardPanel(colorScheme)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(sessions) { session in
                                Button { selectedSession = session } label: { sessionRow(session) }
                                    .buttonStyle(.plain)
                                if session.id != sessions.last?.id { Divider() }
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
            SessionDetailView(session: session, controller: controller)
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

    private func sectionHeading(_ title: LocalizedStringKey, subtitle: LocalizedStringKey, symbol: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(StatisticsStyle.studying)
                .frame(width: 32, height: 32)
                .background(StatisticsStyle.studying.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption.weight(.bold))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func legend(_ title: LocalizedStringKey, color: Color) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 13, height: 5)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func sessionRow(_ session: ActivityInterval) -> some View {
        let annotation = controller.annotation(for: session)
        return HStack(spacing: 14) {
            Image(systemName: "timer")
                .foregroundStyle(StatisticsStyle.studying)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(session.startedAt.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                    .font(.subheadline.weight(.semibold))
                Text("\(session.startedAt.formatted(date: .omitted, time: .shortened)) – \(session.endedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
            Text(StatisticsDuration.label(session.endedAt.timeIntervalSince(session.startedAt)))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func reload() {
        let start = Calendar.current.date(byAdding: .day, value: -6, to: window.start) ?? window.start
        intervals = controller.activityIntervals(from: start, to: now, now: now)
    }
}

private struct SessionDetailView: View {
    let session: ActivityInterval
    let controller: SessionController

    @State private var category: String
    @State private var note: String
    @Environment(\.dismiss) private var dismiss

    init(session: ActivityInterval, controller: SessionController) {
        self.session = session
        self.controller = controller
        let annotation = controller.annotation(for: session)
        _category = State(initialValue: annotation.category)
        _note = State(initialValue: annotation.note)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("dashboard.session.detail").font(.title2.weight(.semibold))
            Text("\(session.startedAt.formatted(date: .abbreviated, time: .shortened)) – \(session.endedAt.formatted(date: .omitted, time: .shortened))")
                .foregroundStyle(.secondary)
            TextField("dashboard.session.category", text: $category)
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
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 430)
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
