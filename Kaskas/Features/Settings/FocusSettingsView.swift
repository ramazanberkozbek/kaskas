import SwiftUI

struct FocusSettingsView: View {
    let controller: SessionController
    @State private var showingDesign = false
    @State private var showingMicroReminderDesign = false

    private let focusDurations: [TimeInterval] = [10, 15, 20, 30, 45, 60, 90].map { $0 * 60 }
    private let breakDurations: [TimeInterval] = [1, 3, 5, 10, 15].map { $0 * 60 }
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
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("settings.schedule.title")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)

                        VStack(spacing: 0) {
                            SettingsDurationRow(
                                title: "settings.focusDuration",
                                subtitle: "settings.focusDuration.description",
                                selection: binding(for: \FocusConfiguration.focusDuration),
                                options: focusDurations
                            )

                            Divider().padding(.horizontal, 16)

                            SettingsDurationRow(
                                title: "settings.breakDuration",
                                subtitle: "settings.breakDuration.description",
                                selection: binding(for: \FocusConfiguration.breakDuration),
                                options: breakDurations
                            )

                            Divider().padding(.horizontal, 16)

                            SettingsDurationRow(
                                title: "settings.snoozeDuration",
                                subtitle: "settings.snoozeDuration.description",
                                selection: binding(for: \FocusConfiguration.snoozeDuration),
                                options: snoozeDurations
                            )
                        }
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.white.opacity(0.1), lineWidth: 1)
                        }

                        Text("settings.nextCycle.note")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                    }

                    Button {
                        showingDesign = true
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "paintpalette")
                                .font(.title3)
                                .frame(width: 28)
                                .foregroundStyle(Color.accentColor)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("settings.focusDesign.title")
                                    .font(.body.weight(.medium))
                                Text("settings.focusDesign.description")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(16)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Button {
                        showingMicroReminderDesign = true
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "sparkles")
                                .font(.title3)
                                .frame(width: 28)
                                .foregroundStyle(Color.accentColor)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("settings.microReminderDesign.title")
                                    .font(.body.weight(.medium))
                                Text("settings.microReminderDesign.description")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(16)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
        }
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
