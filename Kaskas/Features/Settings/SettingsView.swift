import SwiftUI

struct SettingsView: View {
    let controller: SessionController

    @State private var selection: SettingsPane = .focus

    var body: some View {
        TabView(selection: $selection) {
            Tab(
                "settings.sidebar.focus",
                systemImage: "leaf",
                value: SettingsPane.focus
            ) {
                FocusSettingsView(controller: controller)
                    .navigationTitle("settings.sidebar.focus")
            }

            Tab(
                "settings.sidebar.wellness",
                systemImage: "waveform.path.ecg",
                value: SettingsPane.wellness
            ) {
                WellnessSettingsView(controller: controller)
                    .navigationTitle("settings.sidebar.wellness")
            }

            Tab(
                "settings.sidebar.smartPause",
                systemImage: "pause.circle",
                value: SettingsPane.smartPause
            ) {
                SettingsPlaceholderView(pane: .smartPause)
                    .navigationTitle("settings.sidebar.smartPause")
            }

            Tab(
                "settings.sidebar.alerts",
                systemImage: "bell.badge",
                value: SettingsPane.alerts
            ) {
                SettingsPlaceholderView(pane: .alerts)
                    .navigationTitle("settings.sidebar.alerts")
            }

            Tab(
                "settings.sidebar.statistics",
                systemImage: "chart.bar.xaxis",
                value: SettingsPane.statistics
            ) {
                SettingsPlaceholderView(pane: .statistics)
                    .navigationTitle("settings.sidebar.statistics")
            }

            Tab(
                "settings.sidebar.general",
                systemImage: "gearshape",
                value: SettingsPane.general
            ) {
                GeneralSettingsView()
                    .navigationTitle("settings.sidebar.general")
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .frame(
            width: Theme.Size.settingsWidth,
            height: Theme.Size.settingsHeight
        )
    }
}

private enum SettingsPane: String, CaseIterable, Identifiable {
    case focus
    case wellness
    case smartPause
    case alerts
    case statistics
    case general

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .focus: "settings.sidebar.focus"
        case .wellness: "settings.sidebar.wellness"
        case .smartPause: "settings.sidebar.smartPause"
        case .alerts: "settings.sidebar.alerts"
        case .statistics: "settings.sidebar.statistics"
        case .general: "settings.sidebar.general"
        }
    }

    var systemImage: String {
        switch self {
        case .focus: "leaf"
        case .wellness: "waveform.path.ecg"
        case .smartPause: "pause.circle"
        case .alerts: "bell.badge"
        case .statistics: "chart.bar.xaxis"
        case .general: "gearshape"
        }
    }
}

private struct FocusSettingsView: View {
    let controller: SessionController

    private let focusDurations: [TimeInterval] = [10, 15, 20, 30, 45, 60, 90].map { $0 * 60 }
    private let breakDurations: [TimeInterval] = [1, 3, 5, 10, 15].map { $0 * 60 }
    private let snoozeDurations: [TimeInterval] = [3, 5, 10, 15].map { $0 * 60 }

    var body: some View {
        Form {
            Section {
                SettingsDurationRow(
                    title: "settings.focusDuration",
                    subtitle: "settings.focusDuration.description",
                    selection: binding(for: \FocusConfiguration.focusDuration),
                    options: focusDurations
                )

                SettingsDurationRow(
                    title: "settings.breakDuration",
                    subtitle: "settings.breakDuration.description",
                    selection: binding(for: \FocusConfiguration.breakDuration),
                    options: breakDurations
                )

                SettingsDurationRow(
                    title: "settings.snoozeDuration",
                    subtitle: "settings.snoozeDuration.description",
                    selection: binding(for: \FocusConfiguration.snoozeDuration),
                    options: snoozeDurations
                )
            } header: {
                Text("settings.schedule.title")
            } footer: {
                Text("settings.nextCycle.note")
            }
        }
        .formStyle(.grouped)
    }

    private func binding(
        for keyPath: WritableKeyPath<FocusConfiguration, TimeInterval>
    ) -> Binding<TimeInterval> {
        Binding {
            controller.configuration[keyPath: keyPath]
        } set: { newValue in
            var configuration = controller.configuration
            configuration[keyPath: keyPath] = newValue
            controller.updateConfiguration(configuration)
        }
    }
}

private struct WellnessSettingsView: View {
    let controller: SessionController

    private let reminderIntervals: [TimeInterval] = [5, 10, 15, 20, 25, 30].map { $0 * 60 }

    var body: some View {
        Form {
            Section("settings.wellness.section") {
                SettingsDurationRow(
                    title: "settings.reminderInterval",
                    subtitle: "settings.reminderInterval.description",
                    selection: reminderInterval,
                    options: reminderIntervals
                )
            }
        }
        .formStyle(.grouped)
    }

    private var reminderInterval: Binding<TimeInterval> {
        Binding {
            controller.configuration.microReminderInterval
        } set: { newValue in
            var configuration = controller.configuration
            configuration.microReminderInterval = newValue
            controller.updateConfiguration(configuration)
        }
    }
}

private struct SettingsDurationRow: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    @Binding var selection: TimeInterval
    let options: [TimeInterval]

    var body: some View {
        LabeledContent {
            Picker("", selection: $selection) {
                ForEach(options, id: \.self) { duration in
                    Text(Self.formattedDuration(duration))
                        .tag(duration)
                }
            }
            .labelsHidden()
            .frame(width: 170)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private static func formattedDuration(_ seconds: TimeInterval) -> String {
        Measurement(
            value: seconds / 60,
            unit: UnitDuration.minutes
        ).formatted(
            .measurement(width: .wide, usage: .asProvided)
        )
    }
}

private struct SettingsPlaceholderView: View {
    let pane: SettingsPane

    var body: some View {
        ContentUnavailableView {
            Label(pane.title, systemImage: pane.systemImage)
        } description: {
            Text("settings.comingSoon")
        }
    }
}

private struct GeneralSettingsView: View {
    var body: some View {
        Form {
            Section("settings.privacy.title") {
                LabeledContent {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } label: {
                    Label("settings.privacy.local", systemImage: "lock.shield")
                }
            }
        }
        .formStyle(.grouped)
    }
}
