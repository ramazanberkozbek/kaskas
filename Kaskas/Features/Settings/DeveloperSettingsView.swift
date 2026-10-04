import SwiftUI

struct DeveloperSettingsView: View {
    let controller: SessionController
    @AppStorage(DeveloperPreferences.Key.isEnabled) private var isDeveloperModeEnabled = false

    @State private var showsDeleteConfirmation = false
    @State private var showsDeleteError = false
    @State private var historyDeleted = false

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
                            controller.setSpeedMultiplier(1.0)
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

            // MARK: - Time Machine & Simulation Speed
            Section {
                Group {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("developer.time.speed")
                            Spacer()
                            if controller.speedMultiplier > 1.0 {
                                Text("\(Int(controller.speedMultiplier))x")
                                    .font(.system(.caption, design: .monospaced, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.2), in: Capsule())
                                    .foregroundStyle(.orange)
                            }
                        }

                        Picker("developer.time.speed", selection: speedBinding) {
                            Text("1x").tag(1.0)
                            Text("5x").tag(5.0)
                            Text("10x").tag(10.0)
                            Text("30x").tag(30.0)
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("developer.time.fastForward")
                            .font(.callout)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            Button {
                                controller.advanceSession(by: 5 * 60)
                            } label: {
                                Label("developer.time.plus5m", systemImage: "forward.fill")
                            }

                            Button {
                                controller.advanceSession(by: 60 * 60)
                            } label: {
                                Label("developer.time.plus1h", systemImage: "goforward.60")
                            }

                            Button {
                                controller.advanceDay()
                            } label: {
                                Label("developer.time.plus1d", systemImage: "calendar.badge.plus")
                            }

                            Spacer()

                            Button {
                                controller.resetSessionCycle()
                            } label: {
                                Label("developer.time.reset", systemImage: "arrow.clockwise")
                            }
                        }
                    }
                }
                .settingsFormRow()
            } header: {
                sectionHeader("developer.section.timeMachine")
                    .settingsFormSectionHeader()
            }

            // MARK: - Interactive Previews
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
                    Text("developer.history.description")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Button(role: .destructive) {
                        showsDeleteConfirmation = true
                    } label: {
                        Label("developer.history.delete", systemImage: "trash")
                    }
                    .disabled(controller.isDeletingHistory)
                    if controller.isDeletingHistory {
                        ProgressView()
                            .controlSize(.small)
                    } else if historyDeleted {
                        Text("developer.history.deleted")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                .settingsFormRow()
            } header: {
                sectionHeader("developer.section.history")
                    .settingsFormSectionHeader()
            }

            // MARK: - Live Diagnostics
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

            // MARK: - Session Control
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
        .alert("developer.history.confirmTitle", isPresented: $showsDeleteConfirmation) {
            Button("developer.history.delete", role: .destructive) {
                historyDeleted = false
                Task {
                    do {
                        try await controller.deleteHistory()
                        historyDeleted = true
                    } catch {
                        showsDeleteError = true
                    }
                }
            }
            Button("developer.history.cancel", role: .cancel) { }
        } message: {
            Text("developer.history.confirmMessage")
        }
        .alert("developer.history.errorTitle", isPresented: $showsDeleteError) {
            Button("developer.history.ok", role: .cancel) { }
        } message: {
            Text("developer.history.errorMessage")
        }
    }

    private var speedBinding: Binding<Double> {
        Binding {
            controller.speedMultiplier
        } set: { newSpeed in
            controller.setSpeedMultiplier(newSpeed)
        }
    }

    private func sectionHeader(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.primary)
            .textCase(nil)
    }
}
