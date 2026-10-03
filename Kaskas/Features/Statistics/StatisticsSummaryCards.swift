import SwiftUI

struct StatisticsSummaryCards: View {
    let days: [DailyActivity]
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale

    private let summaryKinds: [ActivityKind] = [.studying, .breakTime, .kaskasPaused, .computerInactive]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(summaryKinds, id: \.self) { kind in
                summaryItem(for: kind)
                if kind != summaryKinds.last {
                    Divider()
                        .frame(height: 26)
                        .opacity(0.6)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
        .background(StatisticsStyle.panelFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.primary.opacity(0.08)))
    }

    private func summaryItem(for kind: ActivityKind) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Circle()
                    .fill(kind.color)
                    .frame(width: 7, height: 7)
                Text(LocalizedStringKey(kind.labelKey))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            Text(StatisticsDuration.label(duration(for: kind), locale: locale))
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func duration(for kind: ActivityKind) -> TimeInterval {
        days.reduce(0) { total, day in
            total + day.duration(for: kind) + (kind == .kaskasPaused ? day.duration(for: .meeting) : 0)
        }
    }
}
