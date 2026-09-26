import SwiftUI

struct WellnessSettingsView: View {
    let controller: SessionController

    private let reminderIntervals: [TimeInterval] = [5, 10, 15, 20, 25, 30].map { $0 * 60 }

    var body: some View {
        Form {
            Section("settings.wellness.section") {
                SettingsDurationRow(
                    title: "settings.reminderInterval",
                    subtitle: "settings.reminderInterval.description",
                    selection: reminderInterval,
                    options: reminderIntervals
                )
            }
        }
        .formStyle(.grouped)
    }

    private var reminderInterval: Binding<TimeInterval> {
        Binding {
            controller.configuration.microReminderInterval
        } set: { newValue in
            var configuration = controller.configuration
            configuration.microReminderInterval = newValue
            controller.updateConfiguration(configuration)
        }
    }
}
