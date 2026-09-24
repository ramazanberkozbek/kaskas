import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            Section("settings.general.title") {
                LabeledContent("settings.status.label") {
                    Text("settings.status.ready")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(
            minWidth: Theme.Size.settingsWidth,
            minHeight: Theme.Size.settingsHeight
        )
    }
}
