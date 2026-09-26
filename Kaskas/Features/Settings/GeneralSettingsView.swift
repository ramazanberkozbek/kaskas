import SwiftUI

struct GeneralSettingsView: View {
    let controller: SessionController

    var body: some View {
        Form {
            MenuBarAppearanceSettingsView(controller: controller)
            Section("settings.meetings.section") {
                Toggle(isOn: pauseDuringMeetings) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("settings.meetings.enabled")
                        Text("settings.meetings.description")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Section("settings.privacy.title") {
                LabeledContent {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } label: {
                    Label("settings.privacy.local", systemImage: "lock.shield")
                }
            }
#if DEBUG
            DebugSettingsView(controller: controller)
#endif
        }
        .formStyle(.grouped)
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
}
