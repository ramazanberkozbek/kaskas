import SwiftUI

struct GeneralSettingsView: View {
    let controller: SessionController

    var body: some View {
        Form {
            Section {
                Picker("settings.language.title", selection: appLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        languageOptionRow(for: language)
                            .tag(language)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                sectionHeader("settings.language.section")
            }
            Section {
                Toggle(isOn: launchAtLogin) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("settings.startup.enabled")
                        Text("settings.startup.description")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                if controller.launchAtLogin.requiresApproval {
                    Text("settings.startup.approval")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Button("settings.startup.openSystemSettings") {
                        controller.launchAtLogin.openSystemSettings()
                    }
                }
                if controller.launchAtLogin.updateFailed {
                    Text("settings.startup.error")
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            } header: {
                sectionHeader("settings.startup.section")
            }
            MenuBarAppearanceSettingsView(controller: controller)
            Section {
                Toggle(isOn: pauseDuringMeetings) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("settings.meetings.enabled")
                        Text("settings.meetings.description")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                sectionHeader("settings.meetings.section")
            }
            Section {
                Toggle(isOn: idleDetectionEnabled) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("settings.idle.enabled")
                        Text("settings.idle.description")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                SettingsDurationRow(
                    title: "settings.idle.threshold",
                    subtitle: "settings.idle.threshold.description",
                    selection: idleThreshold,
                    options: [1, 2, 3, 5, 10, 15].map { TimeInterval($0 * 60) }
                )
                .disabled(!controller.configuration.idleDetectionEnabled)
            } header: {
                sectionHeader("settings.idle.section")
            }
#if DEBUG
            DebugSettingsView(controller: controller)
#endif
        }
        .formStyle(.grouped)
        .onAppear { controller.launchAtLogin.refresh() }
    }

    private func sectionHeader(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.primary)
            .textCase(nil)
    }

    private var appLanguage: Binding<AppLanguage> {
        Binding {
            controller.configuration.appLanguage
        } set: { language in
            var configuration = controller.configuration
            configuration.appLanguage = language
            controller.updateConfiguration(configuration)
        }
    }

    private func languageOptionRow(for language: AppLanguage) -> some View {
        Label {
            Text(language.displayName)
        } icon: {
            languageFlagImage(for: language.rawValue)
                .renderingMode(.original)
        }
    }

    private var launchAtLogin: Binding<Bool> {
        Binding {
            controller.launchAtLogin.isEnabled
        } set: { enabled in
            controller.launchAtLogin.setEnabled(enabled)
        }
    }

    private var pauseDuringMeetings: Binding<Bool> {
        Binding {
            controller.configuration.pauseDuringMeetings
        } set: { enabled in
            var configuration = controller.configuration
            configuration.pauseDuringMeetings = enabled
            controller.updateConfiguration(configuration)
        }
    }

    private var idleDetectionEnabled: Binding<Bool> {
        Binding {
            controller.configuration.idleDetectionEnabled
        } set: { enabled in
            var configuration = controller.configuration
            configuration.idleDetectionEnabled = enabled
            controller.updateConfiguration(configuration)
        }
    }

    private var idleThreshold: Binding<TimeInterval> {
        Binding {
            controller.configuration.idleThreshold
        } set: { duration in
            var configuration = controller.configuration
            configuration.idleThreshold = duration
            controller.updateConfiguration(configuration)
        }
    }
}
