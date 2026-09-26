import SwiftUI

struct SettingsDurationRow: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    @Binding var selection: TimeInterval
    let options: [TimeInterval]

    var body: some View {
        LabeledContent {
            Picker(title, selection: $selection) {
                ForEach(options, id: \.self) { duration in
                    Text(Self.formattedDuration(duration))
                        .tag(duration)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 150)
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

    private static func formattedDuration(_ seconds: TimeInterval) -> String {
        Measurement(
            value: seconds / 60,
            unit: UnitDuration.minutes
        ).formatted(
            .measurement(width: .wide, usage: .asProvided)
        )
    }
}
