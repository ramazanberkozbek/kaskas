import SwiftUI

struct SettingsDurationRow: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    @Binding var selection: TimeInterval
    let options: [TimeInterval]

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.medium))
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Picker("", selection: $selection) {
                ForEach(options, id: \.self) { duration in
                    Text(Self.formattedDuration(duration))
                        .tag(duration)
                }
            }
            .labelsHidden()
            .frame(width: 150)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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
