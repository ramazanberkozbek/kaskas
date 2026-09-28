import SwiftUI

struct FocusSettingsView: View {
    let controller: SessionController
    @State private var showingDesign = false
    @State private var showingMicroReminderDesign = false
    @Environment(\.colorScheme) private var colorScheme

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
            settingsContent
        }
    }

    private var settingsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                settingsSection(title: "settings.schedule.title", note: "settings.nextCycle.note") {
                    durationRow("settings.focusDuration", symbol: "timer", tint: .orange,
                                selection: binding(for: \FocusConfiguration.focusDuration), options: focusDurations)
                        .help("settings.focusDuration.description")
                    rowDivider
                    durationRow("settings.breakDuration", symbol: "cup.and.saucer.fill", tint: .orange,
                                selection: binding(for: \FocusConfiguration.breakDuration), options: breakDurations)
                        .help("settings.breakDuration.description")
                    rowDivider
                    durationRow("settings.snoozeDuration", symbol: "clock.arrow.circlepath", tint: .orange,
                                selection: binding(for: \FocusConfiguration.snoozeDuration), options: snoozeDurations)
                        .help("settings.snoozeDuration.description")
                }

                settingsSection(title: "settings.longBreak.title", note: "settings.longBreak.description") {
                    settingRow("settings.longBreak.enabled", symbol: "bed.double.fill", tint: .purple) {
                        Toggle("settings.longBreak.enabled", isOn: binding(for: \FocusConfiguration.longBreakEnabled))
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                    rowDivider
                    settingRow("settings.longBreak.frequency", symbol: "repeat", tint: .purple) {
                        Picker("settings.longBreak.frequency", selection: binding(for: \FocusConfiguration.longBreakFrequency)) {
                            ForEach(1...10, id: \.self) { frequency in
                                Text("Her \(frequency). molada").tag(frequency)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 136)
                    }
                    .disabled(!controller.configuration.longBreakEnabled)
                    .help("settings.longBreak.frequency.description")
                    rowDivider
                    durationRow("settings.longBreak.duration", symbol: "hourglass", tint: .purple,
                                selection: binding(for: \FocusConfiguration.longBreakDuration), options: longBreakDurations)
                        .disabled(!controller.configuration.longBreakEnabled)
                        .help("settings.longBreak.duration.description")
                }

                settingsSection(title: "settings.breakSound.title", note: "settings.breakSound.subtitle") {
                    soundPickerRow(
                        title: "settings.breakSound.startChoice",
                        symbol: "speaker.wave.2.fill",
                        selection: soundSelection(
                            enabled: \FocusConfiguration.breakSoundEnabled,
                            sound: \FocusConfiguration.breakSound
                        )
                    )
                    .help("settings.breakSound.enabledDescription")
                    rowDivider
                    soundPickerRow(
                        title: "settings.breakSound.endChoice",
                        symbol: "speaker.wave.2.fill",
                        selection: soundSelection(
                            enabled: \FocusConfiguration.breakEndSoundEnabled,
                            sound: \FocusConfiguration.breakEndSound
                        )
                    )
                    .help("settings.breakSound.endEnabledDescription")
                }

                settingsSection(title: "settings.focusDesign.title") {
                    settingsDestination("settings.focusDesign.title", symbol: "paintpalette.fill", tint: .pink) {
                        showingDesign = true
                    }
                    .help("settings.focusDesign.description")
                    rowDivider
                    settingsDestination("settings.microReminderDesign.title", symbol: "sparkles", tint: .pink) {
                        showingMicroReminderDesign = true
                    }
                    .help("settings.microReminderDesign.description")
                }
            }
            .frame(maxWidth: 680, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 28)
            .padding(.top, 28)
            .padding(.bottom, 36)
        }
        .background(colorScheme == .dark ? Color(red: 0.075, green: 0.075, blue: 0.075) : Color(nsColor: .windowBackgroundColor))
    }

    private func settingsSection<Content: View>(
        title: LocalizedStringKey,
        note: LocalizedStringKey? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 10)

            VStack(spacing: 0, content: content)
                .background(
                    colorScheme == .dark
                        ? Color(red: 0.115, green: 0.115, blue: 0.115)
                        : Color(nsColor: .controlBackgroundColor),
                    in: RoundedRectangle(cornerRadius: 16)
                )

            if let note {
                Text(note)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 10)
            }
        }
    }

    private var rowDivider: some View {
        Divider().padding(.leading, 58).padding(.trailing, 18)
    }

    private func settingRow<Control: View>(
        _ title: LocalizedStringKey,
        symbol: String,
        tint: Color,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 24)
                .accessibilityHidden(true)
            Text(title)
                .font(.system(size: 14, weight: .medium))
            Spacer(minLength: 12)
            control()
        }
        .frame(minHeight: 58)
        .padding(.horizontal, 18)
    }

    private func durationRow(
        _ title: LocalizedStringKey,
        symbol: String,
        tint: Color,
        selection: Binding<TimeInterval>,
        options: [TimeInterval]
    ) -> some View {
        settingRow(title, symbol: symbol, tint: tint) {
            Picker(title, selection: selection) {
                ForEach(options, id: \.self) { duration in
                    Text(Self.formattedDuration(duration)).tag(duration)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 136)
        }
    }

    private func soundPickerRow(
        title: LocalizedStringKey,
        symbol: String,
        selection: Binding<BreakSound?>
    ) -> some View {
        settingRow(title, symbol: symbol, tint: .green) {
            Picker(title, selection: selection) {
                Text("settings.breakSound.off").tag(nil as BreakSound?)
                ForEach(BreakSound.allCases) { sound in
                    Text(sound.rawValue).tag(Optional(sound))
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 136)
        }
    }

    private func settingsDestination(
        _ title: LocalizedStringKey,
        symbol: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            settingRow(title, symbol: symbol, tint: tint) {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private static func formattedDuration(_ seconds: TimeInterval) -> String {
        Measurement(value: seconds / 60, unit: UnitDuration.minutes)
            .formatted(.measurement(width: .wide, usage: .asProvided))
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
        enabled enabledKeyPath: WritableKeyPath<FocusConfiguration, Bool>,
        sound soundKeyPath: WritableKeyPath<FocusConfiguration, BreakSound>
    ) -> Binding<BreakSound?> {
        Binding {
            let configuration = controller.configuration
            return configuration[keyPath: enabledKeyPath]
                ? configuration[keyPath: soundKeyPath] : nil
        } set: { newValue in
            var configuration = controller.configuration
            let currentValue: BreakSound? = configuration[keyPath: enabledKeyPath]
                ? configuration[keyPath: soundKeyPath] : nil
            guard currentValue != newValue else { return }
            configuration[keyPath: enabledKeyPath] = newValue != nil
            if let newValue {
                configuration[keyPath: soundKeyPath] = newValue
            }
            controller.updateConfiguration(configuration)
            if let newValue {
                BreakSoundPlayer.preview(newValue)
            }
        }
    }
}
