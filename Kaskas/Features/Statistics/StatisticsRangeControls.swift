import SwiftUI

struct StatisticsRangeControls: View {
    @Binding var period: StatisticsPeriod
    @Binding var endDate: Date
    let now: Date

    var body: some View {
        HStack(spacing: 10) {
            StatisticsDateNavigator(
                endDate: $endDate,
                period: period,
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
            .frame(width: 320)
        }
    }
}

private struct StatisticsDateNavigator: View {
    @Binding var endDate: Date
    let period: StatisticsPeriod
    let now: Date
    @Environment(\.locale) private var locale
    @State private var showingCalendar = false

    var body: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        ControlGroup {
            Button {
                endDate = period.shiftedDate(endDate, by: -1, calendar: calendar)
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
                let next = period.shiftedDate(endDate, by: 1, calendar: calendar)
                endDate = min(today, next)
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(period.window(endingAt: endDate).end >= today)
            .accessibilityLabel("stats.nextPeriod")
        }
    }

    private var rangeLabel: String {
        period.rangeLabel(endingAt: endDate, locale: locale)
    }
}
