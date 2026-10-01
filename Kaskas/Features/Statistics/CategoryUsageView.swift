import SwiftUI

struct CategoryUsageView: View {
    let summary: CategoryUsageSummary
    let registry: CategoryRegistry
    let storageFailed: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("categories.usage.title", systemImage: "tag.fill")
                .font(.headline)
            Text("categories.usage.subtitle")
                .font(.caption)
                .foregroundStyle(.secondary)
            if summary.total == 0 {
                Text("categories.usage.empty")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(summary.entries) { entry in
                    let category = registry.historicalCategory(for: entry.categoryID)
                    row(name: category?.name ?? String(localized: "categories.usage.deleted"),
                        symbol: category?.iconName ?? "tag", color: category?.color ?? .secondary,
                        duration: entry.duration)
                }
                if summary.undetected > 0 {
                    row(name: String(localized: "categories.usage.undetected"), symbol: "questionmark.circle",
                        color: .secondary, duration: summary.undetected)
                }
            }
            if storageFailed {
                Label("categories.usage.storageWarning", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(StatisticsStyle.panelFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.primary.opacity(0.08)))
    }

    private func row(name: String, symbol: String, color: Color, duration: TimeInterval) -> some View {
        VStack(spacing: 5) {
            HStack(spacing: 8) {
                Image(systemName: symbol).foregroundStyle(color)
                Text(name)
                Spacer()
                Text(StatisticsDuration.label(duration)).monospacedDigit()
                Text((duration / summary.total).formatted(.percent.precision(.fractionLength(0))))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(minWidth: 38, alignment: .trailing)
            }
            .font(.callout)
            ProgressView(value: duration, total: summary.total).tint(color)
                .accessibilityLabel(name)
        }
    }
}
