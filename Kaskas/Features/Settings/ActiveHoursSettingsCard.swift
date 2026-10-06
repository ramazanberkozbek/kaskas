import SwiftUI

struct ActiveHoursSettingsCard: View {
    let controller: SessionController
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale
    @State private var schedule: ActiveHoursSchedule

    init(controller: SessionController) {
        self.controller = controller
        _schedule = State(initialValue: controller.configuration.activeHours)
    }

    private var calendar: Calendar {
        var calendar = Calendar.autoupdatingCurrent
        calendar.locale = locale
        return calendar
    }

    private var orderedWeekdays: [Int] {
        (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 + 1 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("settings.activeHours.title")
                        .font(.system(size: 13, weight: .semibold))
                    Text("settings.activeHours.description")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("settings.activeHours.title", isOn: $schedule.isEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            VStack(spacing: 0) {
                row("settings.activeHours.days", subtitle: "settings.activeHours.days.description") {
                    HStack(spacing: 0) {
                        ForEach(orderedWeekdays, id: \.self) { day in
                            let selected = schedule.weekdays.contains(day)
                            NativeWeekdayToggle(
                                title: calendar.veryShortStandaloneWeekdaySymbols[day - 1],
                                accessibilityName: calendar.standaloneWeekdaySymbols[day - 1],
                                isSelected: selected,
                                isOnlySelected: schedule.weekdays.count == 1,
                                onToggle: { value in
                                    if value { schedule.weekdays.insert(day) }
                                    else if schedule.weekdays.count > 1 { schedule.weekdays.remove(day) }
                                }
                            )
                            if day != orderedWeekdays.last {
                                Rectangle().fill(.primary.opacity(0.12)).frame(width: 1)
                            }
                        }
                    }
                    .frame(height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay { RoundedRectangle(cornerRadius: 6).stroke(.primary.opacity(0.12), lineWidth: 1) }
                }
                divider
                row("settings.activeHours.start") {
                    SettingsTimePicker(title: "settings.activeHours.start", minute: $schedule.startMinute)
                }
                divider
                row("settings.activeHours.end") {
                    SettingsTimePicker(title: "settings.activeHours.end", minute: $schedule.endMinute)
                }
                divider
                row("settings.activeHours.pauseTracking", subtitle: "settings.activeHours.pauseTracking.description") {
                    Toggle("settings.activeHours.pauseTracking", isOn: $schedule.pausesTracking)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
            }
            .disabled(!schedule.isEnabled)
            .opacity(schedule.isEnabled ? 1 : 0.5)
            .background(colorScheme == .dark ? Color(red: 0.115, green: 0.115, blue: 0.115)
                        : Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
            .contentShape(RoundedRectangle(cornerRadius: 16))
            .onTapGesture {
                NSApp.keyWindow?.makeFirstResponder(nil)
            }

            if schedule.isEnabled {
                if !schedule.isValid {
                    Text("settings.activeHours.invalidTimes")
                        .foregroundStyle(.red)
                        .font(.system(size: 11))
                } else if schedule.spansMidnight {
                    Text("settings.activeHours.overnight")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 11))
                }
            }
        }
        .onChange(of: schedule) { _, value in
            var configuration = controller.configuration
            if value.isValid {
                configuration.activeHours = value
            } else if !value.isEnabled {
                // Disabling must always work, even with an unfinished time edit.
                configuration.activeHours.isEnabled = false
                schedule = configuration.activeHours
            } else {
                return
            }
            controller.updateConfiguration(configuration)
        }
        .onChange(of: controller.configuration.activeHours) { _, value in
            if schedule != value { schedule = value }
        }
    }

    private var divider: some View {
        Divider().padding(.horizontal, SettingsPageLayout.cardInset)
    }

    private func row<Control: View>(_ title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil,
                                   @ViewBuilder control: () -> Control) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13.5, weight: .medium))
                if let subtitle {
                    Text(subtitle).font(.system(size: 11.5)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            control()
        }
        .frame(minHeight: 66)
        .padding(.horizontal, SettingsPageLayout.cardInset)
    }
}

private struct NativeWeekdayToggle: View {
    let title: String
    let accessibilityName: String
    let isSelected: Bool
    let isOnlySelected: Bool
    let onToggle: (Bool) -> Void

    @State private var isHovered = false

    private let selectionColor = Color(red: 0.22, green: 0.54, blue: 0.98)

    private var backgroundColor: Color {
        if isSelected {
            return selectionColor.opacity(isHovered ? 0.40 : 0.28)
        } else if isHovered {
            return Color.primary.opacity(0.08)
        } else {
            return Color.clear
        }
    }

    var body: some View {
        Toggle(isOn: Binding(
            get: { isSelected },
            set: { onToggle($0) }
        )) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 28)
        }
        .toggleStyle(.button)
        .buttonStyle(.borderless)
        .tint(selectionColor)
        .background(backgroundColor)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .accessibilityLabel(accessibilityName)
        .help(accessibilityName)
        .disabled(isSelected && isOnlySelected)
    }
}
