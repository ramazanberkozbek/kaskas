import SwiftUI

struct GeneralSettingsView: View {
    let controller: SessionController

    var body: some View {
        Form {
            Section {
                Group {
                    LabeledContent("settings.language.title") {
                        SettingsMenuPicker(
                            title: "settings.language.title",
                            selection: appLanguage,
                            selectedLabel: Text(controller.configuration.appLanguage.displayName)
                        ) {
                            ForEach(AppLanguage.allCases) { language in
                                languageOptionRow(for: language).tag(language)
                            }
                        }
                    }
                }
                .settingsFormRow()
            } header: {
                VStack(alignment: .leading, spacing: SettingsPageLayout.sectionSpacing) {
                    SettingsPaneHeader(title: "settings.sidebar.general")
                    sectionHeader("settings.language.section")
                }
                .settingsFormSectionHeader()
            }
            Section {
                Group {
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
                }
                .settingsFormRow()
            } header: {
                sectionHeader("settings.startup.section")
                    .settingsFormSectionHeader()
            }
            Section {
                Group {
                    Toggle(isOn: showInDock) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("settings.dock.enabled")
                            Text("settings.dock.description")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .settingsFormRow()
            } header: {
                sectionHeader("settings.dock.section")
                    .settingsFormSectionHeader()
            }
            MenuBarAppearanceSettingsView(controller: controller)
            Section {
                Group {
                    Toggle(isOn: pauseDuringMeetings) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("settings.meetings.enabled")
                            Text("settings.meetings.description")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .settingsFormRow()
            } header: {
                sectionHeader("settings.meetings.section")
                    .settingsFormSectionHeader()
            }
            Section {
                Group {
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
                        options: [1, 3, 5, 10].map { TimeInterval($0 * 60) }
                    )
                    .disabled(!controller.configuration.idleDetectionEnabled)
                }
                .settingsFormRow()
            } header: {
                sectionHeader("settings.idle.section")
                    .settingsFormSectionHeader()
            }
        }
        .settingsGroupedFormLayout()
        .scrollIndicators(.hidden)
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

    private var showInDock: Binding<Bool> {
        Binding {
            controller.configuration.showInDock
        } set: { enabled in
            var configuration = controller.configuration
            configuration.showInDock = enabled
            controller.updateConfiguration(configuration)
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
