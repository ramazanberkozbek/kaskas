import SwiftUI

struct SettingsDurationRow: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    @Binding var selection: TimeInterval
    let options: [TimeInterval]

    var body: some View {
        LabeledContent {
            SettingsDurationPicker(
                title: title,
                selection: $selection,
                options: options,
                minimum: 60,
                validationHint: "settings.duration.idleRange"
            )
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

}
