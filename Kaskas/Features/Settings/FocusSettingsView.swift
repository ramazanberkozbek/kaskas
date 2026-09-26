import SwiftUI

struct FocusSettingsView: View {
    let controller: SessionController
    @State private var showingDesign = false
    @State private var showingMicroReminderDesign = false

    private let focusDurations: [TimeInterval] = [10, 15, 20, 30, 45, 60, 90].map { $0 * 60 }
    private let breakDurations: [TimeInterval] = [1, 3, 5, 10, 15].map { $0 * 60 }
    private let longBreakDurations: [TimeInterval] = [3, 5, 10, 15, 20, 30].map { $0 * 60 }
    private let snoozeDurations: [TimeInterval] = [3, 5, 10, 15].map { $0 * 60 }

    var body: some View {
        if showingDesign {
            FocusDesignView(controller: controller) {
                showingDesign = false
            }
        } else if showingMicroReminderDesign {
            MicroReminderDesignView(controller: controller) {
                showingMicroReminderDesign = false
            }
        } else {
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

                Section {
                    Toggle(isOn: binding(for: \FocusConfiguration.longBreakEnabled)) {
                        settingLabel("settings.longBreak.title", "settings.longBreak.description")
                    }
                    .toggleStyle(.switch)

                    LabeledContent {
                        Stepper(
                            "Her \(controller.configuration.longBreakFrequency). molada",
                            value: binding(for: \FocusConfiguration.longBreakFrequency),
                            in: 1...10
                        )
                        .fixedSize()
                    } label: {
                        settingLabel("settings.longBreak.frequency", "settings.longBreak.frequency.description")
                    }
                    .disabled(!controller.configuration.longBreakEnabled)

                    SettingsDurationRow(
                        title: "settings.longBreak.duration",
                        subtitle: "settings.longBreak.duration.description",
                        selection: binding(for: \FocusConfiguration.longBreakDuration),
                        options: longBreakDurations
                    )
                    .disabled(!controller.configuration.longBreakEnabled)
                } header: {
                    Text("settings.longBreak.title")
                }

                Section {
                    Toggle(isOn: binding(for: \FocusConfiguration.breakSoundEnabled)) {
                        settingLabel("settings.breakSound.enabled", "settings.breakSound.enabledDescription")
                    }
                    .toggleStyle(.switch)

                    soundPickerRow(
                        title: "settings.breakSound.startChoice",
                        selection: soundSelection(for: \FocusConfiguration.breakSound),
                        isEnabled: controller.configuration.breakSoundEnabled
                    )

                    Toggle(isOn: binding(for: \FocusConfiguration.breakEndSoundEnabled)) {
                        settingLabel("settings.breakSound.endEnabled", "settings.breakSound.endEnabledDescription")
                    }
                    .toggleStyle(.switch)

                    soundPickerRow(
                        title: "settings.breakSound.endChoice",
                        selection: soundSelection(for: \FocusConfiguration.breakEndSound),
                        isEnabled: controller.configuration.breakEndSoundEnabled
                    )
                } header: {
                    Text("settings.breakSound.title")
                } footer: {
                    Text("settings.breakSound.subtitle")
                }

                Section {
                    settingsDestination(
                        "settings.focusDesign.title",
                        subtitle: "settings.focusDesign.description",
                        symbol: "paintpalette"
                    ) {
                        showingDesign = true
                    }
                    settingsDestination(
                        "settings.microReminderDesign.title",
                        subtitle: "settings.microReminderDesign.description",
                        symbol: "sparkles"
                    ) {
                        showingMicroReminderDesign = true
                    }
                }
            }
            .formStyle(.grouped)
        }
    }

    private func settingLabel(_ title: LocalizedStringKey, _ subtitle: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func settingsDestination(
        _ title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 22)
                settingLabel(title, subtitle)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func soundPickerRow(
        title: LocalizedStringKey,
        selection: Binding<BreakSound>,
        isEnabled: Bool
    ) -> some View {
        LabeledContent {
            Picker(title, selection: selection) {
                ForEach(BreakSound.allCases) { sound in
                    Text(sound.rawValue).tag(sound)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 150)
        } label: {
            Text(title)
        }
        .disabled(!isEnabled)
    }

    private func binding<Value>(
        for keyPath: WritableKeyPath<FocusConfiguration, Value>
    ) -> Binding<Value> {
        Binding {
            controller.configuration[keyPath: keyPath]
        } set: { newValue in
            var configuration = controller.configuration
            configuration[keyPath: keyPath] = newValue
            controller.updateConfiguration(configuration)
        }
    }

    private func soundSelection(
        for keyPath: WritableKeyPath<FocusConfiguration, BreakSound>
    ) -> Binding<BreakSound> {
        Binding {
            controller.configuration[keyPath: keyPath]
        } set: { newValue in
            guard controller.configuration[keyPath: keyPath] != newValue else { return }
            var configuration = controller.configuration
            configuration[keyPath: keyPath] = newValue
            controller.updateConfiguration(configuration)
            BreakSoundPlayer.preview(newValue)
        }
    }
}
