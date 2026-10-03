#if DEBUG
import SwiftUI

/// Development-only controls, excluded from Release builds.
struct DebugSettingsView: View {
    let controller: SessionController

    @AppStorage(DebugPreferences.Key.modeEnabled, store: DebugPreferences.store) private var isEnabled = false
    @AppStorage(DebugPreferences.Key.sessionDetailsEnabled, store: DebugPreferences.store) private var sessionDetailsEnabled = false

    var body: some View {
        Section {
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
        } header: {
            Text("debug.title")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .textCase(nil)
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
