import SwiftUI

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
            .frame(width: 180)
        }
    }
}

private struct StatisticsDateNavigator: View {
    @Binding var endDate: Date
    let startDate: Date
    let stepDays: Int
    let now: Date
    @Environment(\.locale) private var locale
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
                    .environment(\.locale, locale)
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
        let start = startDate.formatted(.dateTime.day().month(.abbreviated).year().locale(locale))
        let end = endDate.formatted(.dateTime.day().month(.abbreviated).year().locale(locale))
        return stepDays == 1 ? end : "\(start)–\(end)"
    }
}
