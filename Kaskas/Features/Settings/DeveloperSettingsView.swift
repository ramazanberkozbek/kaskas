import SwiftUI

struct DeveloperSettingsView: View {
    let controller: SessionController
    @AppStorage(DeveloperPreferences.Key.isEnabled) private var isDeveloperModeEnabled = false

    var body: some View {
        Form {
            Section {
                Group {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("developer.banner.title")
                                .font(.headline)
                            Text("developer.banner.description")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("developer.turnOff") {
                            isDeveloperModeEnabled = false
                            controller.dismissPreviews()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .settingsFormRow()
            } header: {
                VStack(alignment: .leading, spacing: SettingsPageLayout.sectionSpacing) {
                    SettingsPaneHeader(title: "settings.sidebar.developer")
                    sectionHeader("developer.section.status")
                }
                .settingsFormSectionHeader()
            }

            Section {
                Group {
                    Button {
                        controller.previewBreak()
                    } label: {
                        Label("developer.preview.break", systemImage: "cup.and.saucer.fill")
                    }

                    Button {
                        controller.previewMicroReminder()
                    } label: {
                        Label("developer.preview.microReminder", systemImage: "eye.fill")
                    }

                    Button {
                        controller.previewBreakWarning()
                    } label: {
                        Label("developer.preview.breakWarning", systemImage: "bell.badge.fill")
                    }

                    Button {
                        controller.previewSkippedBreakReminder()
                    } label: {
                        Label("developer.preview.skippedBreak", systemImage: "forward.fill")
                    }

                    Button {
                        controller.previewIdleBreak()
                    } label: {
                        Label("developer.preview.idleBreak", systemImage: "moon.fill")
                    }

                    Button(role: .destructive) {
                        controller.dismissPreviews()
                    } label: {
                        Label("developer.dismissPreviews", systemImage: "xmark.circle")
                    }
                }
                .settingsFormRow()
            } header: {
                sectionHeader("developer.section.previews")
                    .settingsFormSectionHeader()
            }

            Section {
                Group {
                    let snapshot = controller.sessionSnapshot
                    LabeledContent("developer.live.phase") {
                        Text(snapshot.phase == .focusing ? "developer.phase.focusing" : "developer.phase.onBreak")
                            .foregroundStyle(snapshot.phase == .focusing ? .blue : .green)
                            .font(.system(.body, design: .monospaced))
                    }

                    LabeledContent("developer.live.breaksToday") {
                        Text(controller.breaksTakenToday(at: Date.now).formatted())
                            .font(.system(.body, design: .monospaced))
                    }

                    LabeledContent("developer.live.remaining") {
                        Text("\(Int(max(0, snapshot.remaining))) s")
                            .font(.system(.body, design: .monospaced))
                    }
                }
                .settingsFormRow()
            } header: {
                sectionHeader("developer.section.diagnostics")
                    .settingsFormSectionHeader()
            }

            Section {
                Group {
                    HStack(spacing: 12) {
                        Button("developer.action.startBreak") {
                            controller.startBreakNow()
                        }
                        Button("developer.action.completeBreak") {
                            controller.completeBreak()
                        }
                        Button("developer.action.togglePause") {
                            controller.toggleManualPause()
                        }
                    }
                }
                .settingsFormRow()
            } header: {
                sectionHeader("developer.section.sessionControl")
                    .settingsFormSectionHeader()
            }
        }
        .settingsGroupedFormLayout()
        .scrollIndicators(.hidden)
    }

    private func sectionHeader(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.primary)
            .textCase(nil)
    }
}
