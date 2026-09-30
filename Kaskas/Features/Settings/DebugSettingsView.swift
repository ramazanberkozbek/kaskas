#if DEBUG
import SwiftUI

/// Development-only controls. Remove this file and the guarded section in
/// SettingsView to remove the debug UI entirely.
struct DebugSettingsView: View {
    let controller: SessionController

    @AppStorage("debugModeEnabled") private var isEnabled = false
    @AppStorage("debugSessionDetailsEnabled") private var sessionDetailsEnabled = false

    var body: some View {
        Section("debug.title") {
            Toggle("debug.enable", isOn: $isEnabled)

            if isEnabled {
                Toggle("debug.sessionDetails", isOn: $sessionDetailsEnabled)

                Text("debug.description")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("debug.microReminder") {
                    controller.previewMicroReminder()
                }

                Button("debug.breakWarning") {
                    controller.previewBreakWarning()
                }

                Button("debug.skippedBreakReminder") {
                    controller.previewSkippedBreakReminder()
                }

                Button("debug.break") {
                    controller.previewBreak()
                }

                Button("debug.dismissPreviews") {
                    controller.dismissPreviews()
                }

                LabeledContent("debug.session") {
                    if controller.sessionSnapshot.phase == .focusing {
                        Text("debug.focusing")
                    } else {
                        Text("debug.onBreak")
                    }
                }

                LabeledContent("debug.breaksToday") {
                    Text(controller.breaksTakenToday().formatted())
                }
            }
        }
        .onChange(of: isEnabled) { _, enabled in
            if !enabled {
                sessionDetailsEnabled = false
                controller.dismissPreviews()
            }
        }
    }
}
#endif
